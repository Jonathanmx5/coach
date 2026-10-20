// Robustesse du relais : quota rendu en cas d'échec, erreurs KV, format et
// taille de l'entrée, délais des modèles, fin de génération de Gemini.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { requeteGemini } from '../src/gemini.js';
import { quotaWorkersEpuise, traiter } from '../src/index.js';
import { consommer, jourUtc, rendre } from '../src/limites.js';

const PROJET = 'coach-test';
const MAINTENANT = Date.UTC(2026, 9, 9, 12);
const JOUR = jourUtc(MAINTENANT);
const CLE_G = `g:${JOUR}`;
const CLE_U = `u:u1:${JOUR}`;
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2]);
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const POMME = { response: '{"aliments":[{"nom":"pomme","grammes":150,"kcal":78}]}' };

const b64u = (octets) =>
  Buffer.from(octets).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const json64 = (o) => b64u(new TextEncoder().encode(JSON.stringify(o)));

// Jeton Firebase signé par une clé de test.
async function fabrique() {
  const paire = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = { ...(await crypto.subtle.exportKey('jwk', paire.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
  const e = json64({ alg: 'RS256', kid: 'k1', typ: 'JWT' });
  const c = json64({
    iss: `https://securetoken.google.com/${PROJET}`,
    aud: PROJET,
    sub: 'u1',
    iat: MAINTENANT / 1000 - 60,
    exp: MAINTENANT / 1000 + 3000,
  });
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', paire.privateKey, new TextEncoder().encode(`${e}.${c}`));
  return { cles: async () => ({ keys: [jwk] }), jeton: `${e}.${c}.${b64u(new Uint8Array(sig))}` };
}

/** Faux KV : [panne] fait échouer put (429 de KV), [lent] rend chaque accès asynchrone. */
function fauxKv({ initial = {}, panne = false, lent = false } = {}) {
  const m = new Map(Object.entries(initial));
  const pause = () => (lent ? new Promise((r) => setImmediate(r)) : undefined);
  return {
    m,
    get: async (k) => (await pause(), m.get(k) ?? null),
    put: async (k, v) => {
      await pause();
      if (panne) throw new Error('KV PUT failed: 429 Too Many Requests');
      m.set(k, v);
    },
  };
}

function fauxIa(reponse = async () => POMME) {
  const appels = [];
  return {
    appels,
    run: async (modele, entree) => {
      appels.push({ modele, entree });
      return reponse(modele, entree);
    },
  };
}

const env = ({ ia = fauxIa(), kv = fauxKv(), ...autres } = {}) => ({
  PROJECT_ID: PROJET,
  MODELE: 'principal',
  MODELE_SECOURS: 'secours',
  PLAFOND_UTILISATEUR: '2',
  PLAFOND_GLOBAL: '10',
  LIMITES: kv,
  AI: ia,
  ...autres,
});

const requete = (jeton, corps = JPEG, adresse = 'https://relais.test/analyse') =>
  new Request(adresse, { method: 'POST', headers: { authorization: `Bearer ${jeton}` }, body: corps });

const texteConsigne = (appel) => appel.entree.messages[0].content[0].text;

test('erreur KV (écriture refusée) : réponse JSON 503, pas de plantage', async () => {
  const { cles, jeton } = await fabrique();
  const ia = fauxIa();
  const r = await traiter(requete(jeton), env({ ia, kv: fauxKv({ panne: true }) }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 503);
  assert.match(r.headers.get('content-type'), /application\/json/);
  assert.deepEqual(await r.json(), { erreur: 'ia' });
  assert.equal(ia.appels.length, 0);
});

test('erreur imprévue : toujours du JSON (503)', async () => {
  const { cles, jeton } = await fabrique();
  const casse = {
    url: 'https://relais.test/analyse',
    method: 'POST',
    headers: new Headers({ authorization: `Bearer ${jeton}` }),
    arrayBuffer: async () => {
      throw new TypeError('flux interrompu');
    },
  };
  const r = await traiter(casse, env(), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 503);
  assert.deepEqual(await r.json(), { erreur: 'ia' });
});

test('IA en panne : 502 et compteurs revenus à leur valeur initiale', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv({ initial: { [CLE_G]: '4', [CLE_U]: '1' } });
  const ia = fauxIa(async () => {
    throw new Error('panne');
  });
  const r = await traiter(requete(jeton), env({ ia, kv }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 502);
  assert.deepEqual(ia.appels.map((a) => a.modele), ['principal', 'secours']);
  assert.equal(kv.m.get(CLE_G), '4');
  assert.equal(kv.m.get(CLE_U), '1');
});

test('réponse illisible (422) : unité rendue, via ctx.waitUntil quand il existe', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const differees = [];
  const ctx = { waitUntil: (p) => differees.push(p) };
  const ia = fauxIa(async () => ({ response: 'désolé, je ne peux pas' }));
  const r = await traiter(requete(jeton), env({ ia, kv }), { cles, maintenant: MAINTENANT, ctx });
  assert.equal(r.status, 422);
  assert.equal(differees.length, 1);
  await Promise.all(differees);
  assert.equal(kv.m.get(CLE_G), '0');
  assert.equal(kv.m.get(CLE_U), '0');
});

test('succès : unité gardée, photos restantes dans la réponse', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const e = env({ kv });
  const deps = { cles, maintenant: MAINTENANT };
  const r1 = await traiter(requete(jeton), e, deps);
  assert.equal(r1.status, 200);
  assert.equal((await r1.json()).restantes, 1);
  assert.equal((await (await traiter(requete(jeton), e, deps)).json()).restantes, 0);
  assert.equal(kv.m.get(CLE_U), '2');
  assert.equal((await traiter(requete(jeton), e, deps)).status, 429);
});

test('rendre : décrémente les deux compteurs, jamais sous 0', async () => {
  const kv = fauxKv({ initial: { [CLE_G]: '1' } });
  await rendre(kv, 'u1', JOUR);
  await rendre(kv, 'u1', JOUR);
  assert.equal(kv.m.get(CLE_G), '0');
  assert.equal(kv.m.has(CLE_U), false);
  // Une panne de KV n'est pas propagée.
  await rendre(fauxKv({ initial: { [CLE_G]: '3' }, panne: true }), 'u1', JOUR);
});

test('corps PNG : 415 sans consommer de quota ni appeler l\'IA', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const ia = fauxIa();
  const r = await traiter(requete(jeton, PNG), env({ ia, kv }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 415);
  assert.deepEqual(await r.json(), { erreur: 'format' });
  assert.equal(kv.m.size, 0);
  assert.equal(ia.appels.length, 0);
});

test('content-length trop grand : 413 sans lire le corps', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  let lu = false;
  const enorme = {
    url: 'https://relais.test/analyse',
    method: 'POST',
    headers: new Headers({ authorization: `Bearer ${jeton}`, 'content-length': '50000000' }),
    arrayBuffer: async () => ((lu = true), new ArrayBuffer(0)),
    formData: async () => ((lu = true), new FormData()),
  };
  const r = await traiter(enorme, env({ kv }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 413);
  assert.deepEqual(await r.json(), { erreur: 'taille' });
  assert.equal(lu, false);
  assert.equal(kv.m.size, 0);
});

test('multipart avec indice : précision et image transmises au modèle', async () => {
  const { cles, jeton } = await fabrique();
  const ia = fauxIa();
  const formulaire = new FormData();
  formulaire.append('indice', 'sauce à part');
  formulaire.append('image', new Blob([JPEG], { type: 'image/jpeg' }), 'repas.jpg');
  const r = await traiter(requete(jeton, formulaire), env({ ia }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 200);
  assert.equal((await r.json()).aliments[0].nom, 'pomme');
  assert.match(texteConsigne(ia.appels[0]), /« sauce à part »/);
  // L'image transmise est bien celle de la partie « image ».
  const url = ia.appels[0].entree.messages[0].content[1].image_url.url;
  assert.equal(url, `data:image/jpeg;base64,${Buffer.from(JPEG).toString('base64')}`);
});

test('multipart sans image, ou image PNG : 415', async () => {
  const { cles, jeton } = await fabrique();
  const sansImage = new FormData();
  sansImage.append('indice', 'x');
  const png = new FormData();
  png.append('image', new Blob([PNG], { type: 'image/png' }), 'x.png');
  for (const corps of [sansImage, png]) {
    const kv = fauxKv();
    const r = await traiter(requete(jeton, corps), env({ kv }), { cles, maintenant: MAINTENANT });
    assert.equal(r.status, 415);
    assert.equal(kv.m.size, 0);
  }
});

test('ancien format (corps brut, ?indice=) toujours accepté', async () => {
  const { cles, jeton } = await fabrique();
  const ia = fauxIa();
  const adresse = 'https://relais.test/analyse?indice=' + encodeURIComponent('la moitié');
  const r = await traiter(requete(jeton, JPEG, adresse), env({ ia }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 200);
  assert.match(texteConsigne(ia.appels[0]), /la moitié/);
});

function fauxFetch(reponses) {
  const appels = [];
  const f = async (url, init) => {
    appels.push({ url, init });
    return new Response(JSON.stringify(reponses.shift()), { status: 200 });
  };
  return { f, appels };
}

const geminiAvecFin = (finishReason) => ({
  candidates: [
    {
      content: { parts: [{ text: '{"aliments":[{"nom":"Riz","grammes":180,"kcal":234}]}' }] },
      finishReason,
    },
  ],
  usageMetadata: { promptTokenCount: 1300, candidatesTokenCount: 90, thoughtsTokenCount: 40 },
});

test('Gemini coupé (finishReason MAX_TOKENS) : repli sur Workers AI', async () => {
  const { cles, jeton } = await fabrique();
  for (const fin of ['MAX_TOKENS', 'SAFETY', undefined]) {
    const ia = fauxIa();
    const { f, appels } = fauxFetch([geminiAvecFin(fin)]);
    const r = await traiter(requete(jeton), env({ ia, GEMINI_API_KEY: 'k' }), {
      cles,
      maintenant: MAINTENANT,
      fetcher: f,
    });
    assert.equal(r.status, 200);
    assert.equal((await r.json()).aliments[0].nom, 'pomme');
    assert.equal(appels.length, 1);
    assert.deepEqual(ia.appels.map((a) => a.modele), ['principal']);
  }
});

test('Gemini terminé (STOP) : réponse gardée ; délai et réflexion bornés', async () => {
  const { cles, jeton } = await fabrique();
  const ia = fauxIa();
  const { f, appels } = fauxFetch([geminiAvecFin('STOP')]);
  const r = await traiter(requete(jeton), env({ ia, GEMINI_API_KEY: 'k' }), {
    cles,
    maintenant: MAINTENANT,
    fetcher: f,
  });
  assert.equal((await r.json()).aliments[0].nom, 'Riz');
  assert.equal(ia.appels.length, 0);
  assert.ok(appels[0].init.signal instanceof AbortSignal, 'délai maximal sur le fetch');
  const config = JSON.parse(appels[0].init.body).generationConfig;
  assert.deepEqual(config.thinkingConfig, { thinkingLevel: 'low' });
  // Les modèles 2.x prennent un budget en jetons.
  const ancien = JSON.parse(requeteGemini(JPEG, '', { cle: 'k', modele: 'gemini-2.5-flash' }).init.body);
  assert.deepEqual(ancien.generationConfig.thinkingConfig, { thinkingBudget: 512 });
});

test('journal d\'usage : modèle et jetons, sans indice ni contenu', async (t) => {
  const { cles, jeton } = await fabrique();
  const lignes = [];
  t.mock.method(console, 'log', (l) => lignes.push(String(l)));
  const ia = fauxIa(async () => ({ ...POMME, usage: { prompt_tokens: 1500, completion_tokens: 60 } }));
  const { f } = fauxFetch([geminiAvecFin('MAX_TOKENS')]);
  const adresse = 'https://relais.test/analyse?indice=' + encodeURIComponent('je suis coeliaque');
  await traiter(requete(jeton, JPEG, adresse), env({ ia, GEMINI_API_KEY: 'k' }), {
    cles,
    maintenant: MAINTENANT,
    fetcher: f,
  });
  const journal = JSON.parse(lignes.find((l) => l.startsWith('{"analyse"')));
  assert.equal(journal.analyse, 200);
  assert.deepEqual(journal.essais, [
    { modele: 'gemini-3.8-flash', entree: 1300, sortie: 90, reflexion: 40, ok: false, erreur: 'echec' },
    { modele: 'principal', entree: 1500, sortie: 60, ok: true },
  ]);
  const tout = lignes.join('\n');
  assert.equal(tout.includes('coeliaque'), false);
  assert.equal(tout.includes('pomme'), false);
  assert.equal(tout.includes('u1'), false);
});

test('budget de temps : le secours est sauté s\'il reste moins de 12 s', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const ia = fauxIa(async () => {
    throw new Error('panne');
  });
  // 25 s déjà écoulées après le début : il en reste 10.
  let appel = 0;
  const horloge = () => (appel++ === 0 ? 0 : 25_000);
  const r = await traiter(requete(jeton), env({ ia, kv }), { cles, maintenant: MAINTENANT, horloge });
  assert.equal(r.status, 502);
  assert.deepEqual(ia.appels.map((a) => a.modele), ['principal']);
  assert.equal(kv.m.get(CLE_U), '0');
});

test('modèle qui ne répond pas : coupé au bout du budget, 502 et unité rendue', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const ia = fauxIa(() => new Promise(() => {}));
  // Il ne reste que 20 ms du budget.
  let appel = 0;
  const horloge = () => (appel++ === 0 ? 0 : 34_980);
  const r = await traiter(requete(jeton), env({ ia, kv }), { cles, maintenant: MAINTENANT, horloge });
  assert.equal(r.status, 502);
  assert.deepEqual(ia.appels.map((a) => a.modele), ['principal']);
  assert.equal(kv.m.get(CLE_G), '0');
});

test('quota Workers AI épuisé : 429 « service », secours non appelé, unité rendue', async () => {
  const { cles, jeton } = await fabrique();
  const kv = fauxKv();
  const ia = fauxIa(async () => {
    throw new Error('3036: Account limited: you have used up your daily free allocation of 10,000 neurons');
  });
  const r = await traiter(requete(jeton), env({ ia, kv }), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 429);
  assert.deepEqual(await r.json(), { erreur: 'quota', raison: 'service' });
  assert.deepEqual(ia.appels.map((a) => a.modele), ['principal']);
  assert.equal(kv.m.get(CLE_U), '0');
  assert.equal(quotaWorkersEpuise(new Error('panne réseau')), false);
});

test('limite connue (KV non atomique) : une rafale simultanée dépasse le plafond', async () => {
  // Ce test DOCUMENTE la limite actuelle, en attendant la décision sur un
  // Durable Object ou D1 : N requêtes simultanées lisent toutes la même
  // valeur, passent toutes (dépassement de N-1 au plus) et le compteur
  // n'avance que d'une unité. Une correction atomique le fera échouer : il
  // faudra alors exiger exactement le plafond.
  const kv = fauxKv({ lent: true });
  const opt = { plafondUtilisateur: 2, plafondGlobal: 100, maintenant: MAINTENANT };
  const N = 5;
  const resultats = await Promise.all(Array.from({ length: N }, () => consommer(kv, 'u1', opt)));
  const acceptees = resultats.filter((r) => r.ok).length;
  assert.ok(acceptees > opt.plafondUtilisateur, 'dépassement attendu tant que KV est utilisé');
  assert.ok(acceptees <= opt.plafondUtilisateur + N - 1);
  assert.equal(kv.m.get(CLE_U), '1');
});
