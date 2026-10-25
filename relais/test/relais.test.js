import assert from 'node:assert/strict';
import { test } from 'node:test';

import { CONSIGNE, aliments, analyse, depuisTexteLibre, entreeModele, extraireJson, nettoyerIndice } from '../src/analyse.js';
import { traiter } from '../src/index.js';
import { JetonInvalide, verifierAppCheck, verifierJeton } from '../src/jeton.js';
import { consommer, jourUtc } from '../src/limites.js';

const PROJET = 'coach-test';
const MAINTENANT = Date.UTC(2026, 9, 9, 12);

const b64u = (octets) =>
  Buffer.from(octets).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const json64 = (o) => b64u(new TextEncoder().encode(JSON.stringify(o)));

async function fabrique() {
  const paire = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = { ...(await crypto.subtle.exportKey('jwk', paire.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
  const cles = async () => ({ keys: [jwk] });
  async function jeton(charge = {}, entete = {}) {
    const e = json64({ alg: 'RS256', kid: 'k1', typ: 'JWT', ...entete });
    const c = json64({
      iss: `https://securetoken.google.com/${PROJET}`,
      aud: PROJET,
      sub: 'u1',
      iat: MAINTENANT / 1000 - 60,
      exp: MAINTENANT / 1000 + 3000,
      ...charge,
    });
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', paire.privateKey, new TextEncoder().encode(`${e}.${c}`));
    return `${e}.${c}.${b64u(new Uint8Array(sig))}`;
  }
  return { cles, jeton };
}

const verifier = (jeton, cles) => verifierJeton(jeton, { projectId: PROJET, cles, maintenant: MAINTENANT });

test('jeton valide : renvoie l\'uid', async () => {
  const { cles, jeton } = await fabrique();
  assert.equal(await verifier(await jeton(), cles), 'u1');
});

test('jeton refusé : expiré, mauvais projet, signature altérée, format, clé inconnue', async () => {
  const { cles, jeton } = await fabrique();
  await assert.rejects(verifier(await jeton({ exp: MAINTENANT / 1000 - 1 }), cles), JetonInvalide);
  await assert.rejects(verifier(await jeton({ aud: 'autre' }), cles), JetonInvalide);
  await assert.rejects(verifier(await jeton({ iss: 'https://securetoken.google.com/autre' }), cles), JetonInvalide);
  await assert.rejects(verifier(await jeton({ sub: '' }), cles), JetonInvalide);
  await assert.rejects(verifier(await jeton({}, { kid: 'zzz' }), cles), JetonInvalide);
  await assert.rejects(verifier(await jeton({}, { alg: 'none' }), cles), JetonInvalide);
  const bon = await jeton();
  const altere = bon.slice(0, -4) + (bon.endsWith('AAAA') ? 'BBBB' : 'AAAA');
  await assert.rejects(verifier(altere, cles), JetonInvalide);
  await assert.rejects(verifier('abc', cles), JetonInvalide);
  await assert.rejects(verifier('', cles), JetonInvalide);
});

function faux() {
  const m = new Map();
  return { get: async (k) => m.get(k) ?? null, put: async (k, v) => void m.set(k, v), m };
}

test('limites : plafond par utilisateur et global, par jour UTC', async () => {
  const kv = faux();
  const opt = { plafondUtilisateur: 2, plafondGlobal: 3, maintenant: MAINTENANT };
  assert.equal((await consommer(kv, 'a', opt)).ok, true);
  assert.equal((await consommer(kv, 'a', opt)).ok, true);
  assert.deepEqual(await consommer(kv, 'a', opt), { ok: false, raison: 'utilisateur' });
  assert.equal((await consommer(kv, 'b', opt)).ok, true);
  assert.deepEqual(await consommer(kv, 'c', opt), { ok: false, raison: 'global' });
  // Le lendemain, les compteurs repartent.
  assert.equal((await consommer(kv, 'a', { ...opt, maintenant: MAINTENANT + 86_400_000 })).ok, true);
  assert.equal(jourUtc(MAINTENANT), '2026-10-09');
});

test('un refus global ne consomme pas le quota utilisateur', async () => {
  const kv = faux();
  const opt = { plafondUtilisateur: 5, plafondGlobal: 1, maintenant: MAINTENANT };
  await consommer(kv, 'a', opt);
  await consommer(kv, 'b', opt);
  assert.equal(kv.m.get(`u:b:${jourUtc(MAINTENANT)}`), undefined);
});

test('extraction JSON : avec texte et balises', () => {
  assert.deepEqual(extraireJson('Voici :\n```json\n{"aliments":[]}\n```'), { aliments: [] });
  assert.equal(extraireJson('pas de json'), null);
  assert.equal(extraireJson('{cassé'), null);
});

test('extraction JSON : réponse coupée en plein milieu', () => {
  const coupee = '{"aliments":[{"nom":"Pain","grammes":50,"kcal":130},{"nom":"Fromage","grammes":30,"kcal":1';
  assert.deepEqual(aliments(coupee).map((a) => a.nom), ['Pain']);
  assert.equal(extraireJson('{"aliments":[{"nom":"x'), null);
});

test('aliments : nettoyage, bornes, kcal recalculées', () => {
  const sortie = aliments(
    '{"aliments":[{"nom":" Riz ","grammes":150,"kcal":195,"proteines":4,"glucides":42,"lipides":0.5},' +
      '{"nom":"Poulet","grammes":"120","proteines":30,"glucides":0,"lipides":4},' +
      '{"nom":"","grammes":10},{"grammes":5},{"nom":"Fou","grammes":99999,"kcal":99999}]}',
  );
  assert.equal(sortie.length, 3);
  assert.equal(sortie[0].nom, 'Riz');
  assert.equal(sortie[1].grammes, 120);
  assert.equal(sortie[1].kcal, 156); // 30×4 + 0×4 + 4×9
  assert.equal(sortie[2].grammes, 2000);
  assert.equal(sortie[2].kcal, 3000);
  assert.equal(aliments('rien'), null);
  assert.deepEqual(aliments('{"aliments":[]}'), []);
});

test('aliments : confiance bornée, 0,5 par défaut (sous le seuil « à vérifier »)', () => {
  const l = aliments({
    aliments: [
      { nom: 'a', grammes: 10, kcal: 10, confiance: 3 },
      { nom: 'b', grammes: 10, kcal: 10, confiance: -1 },
      { nom: 'c', grammes: 10, kcal: 10 },
      { nom: 'd', grammes: 10, kcal: 10, confiance: '0.4' },
      // Grammes devinés (100 par défaut) : confiance plafonnée à 0,5.
      { nom: 'e', kcal: 10, confiance: 0.9 },
    ],
  });
  assert.deepEqual(l.map((x) => x.confiance), [1, 0, 0.5, 0.4, 0.5]);
  assert.equal(l[4].grammes, 100);
});

test('aliments : calories incohérentes avec les macros corrigées', () => {
  const [faux, bon, sansMacros] = aliments({
    aliments: [
      { nom: 'x', grammes: 100, kcal: 900, proteines: 10, glucides: 20, lipides: 5 },
      { nom: 'y', grammes: 100, kcal: 150, proteines: 10, glucides: 20, lipides: 3 },
      { nom: 'z', grammes: 100, kcal: 120 },
    ],
  });
  assert.equal(faux.kcal, 165); // 10×4 + 20×4 + 5×9
  assert.equal(bon.kcal, 150); // à moins de 25 % : conservé
  assert.equal(sansMacros.kcal, 120); // pas de macros : conservé
});

test("précision de l'utilisateur : nettoyée et ajoutée à la consigne", () => {
  assert.equal(nettoyerIndice('  sauce   à part\n{ignore}  '), 'sauce à part ignore');
  assert.equal(nettoyerIndice(42), '');
  assert.equal(nettoyerIndice('x'.repeat(500)).length, 200);
  const texte = (i) => entreeModele(new Uint8Array([1]), i).messages[0].content[0].text;
  assert.ok(!texte('').includes('Précision donnée'));
  assert.ok(texte('grande portion').includes('« grande portion »'));
});

test('aliments : 8 au plus', () => {
  const beaucoup = { aliments: Array.from({ length: 20 }, (_, i) => ({ nom: `a${i}`, grammes: 10, kcal: 10 })) };
  assert.equal(aliments(beaucoup).length, 8);
});

// Début d'un JPEG (octets magiques FF D8 FF) : le relais refuse les autres formats.
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);

function requete({ jeton, corps = JPEG, methode = 'POST', chemin = '/analyse' } = {}) {
  return new Request(`https://relais.test${chemin}`, {
    method: methode,
    headers: jeton ? { authorization: `Bearer ${jeton}` } : {},
    body: methode === 'POST' ? corps : undefined,
  });
}

function env(ia) {
  return {
    PROJECT_ID: PROJET,
    MODELE: 'm',
    PLAFOND_UTILISATEUR: '2',
    PLAFOND_GLOBAL: '10',
    LIMITES: faux(),
    AI: { run: ia ?? (async () => ({ response: '{"aliments":[{"nom":"pomme","grammes":150,"kcal":78}]}' })) },
  };
}

test('produit emballé : description, sucres et saturés bornés', () => {
  const r = analyse(
    '{"description":"  Gâteau de semoule protéiné Aldi  ","aliments":[{"nom":"Gâteau de semoule","grammes":250,"kcal":202,"proteines":20,"glucides":22,"sucres":11.5,"lipides":3.75,"satures":2.5,"confiance":0.9}]}',
  );
  assert.equal(r.description, 'Gâteau de semoule protéiné Aldi');
  const a = r.aliments[0];
  assert.equal(a.sucres, 11.5);
  assert.equal(a.satures, 2.5);
  assert.equal(a.kcal, 202);
  // Sucres et saturés ne dépassent jamais glucides et lipides.
  const b = analyse({ aliments: [{ nom: 'x', grammes: 10, glucides: 5, sucres: 50, lipides: 1, satures: 9 }] }).aliments[0];
  assert.equal(b.sucres, 5);
  assert.equal(b.satures, 1);
  assert.equal(analyse({ aliments: [] }).description, '');
  assert.equal(analyse('rien'), null);
});

test('relais : parcours complet', async () => {
  const { cles, jeton } = await fabrique();
  const r = await traiter(requete({ jeton: await jeton() }), env(), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.aliments[0].nom, 'pomme');
  assert.equal(typeof j.description, 'string');
});

test('relais : sans jeton 401, mauvaise route 404, mauvaise méthode 405', async () => {
  const { cles } = await fabrique();
  const deps = { cles, maintenant: MAINTENANT };
  assert.equal((await traiter(requete(), env(), deps)).status, 401);
  assert.equal((await traiter(requete({ chemin: '/autre' }), env(), deps)).status, 404);
  assert.equal((await traiter(requete({ methode: 'GET' }), env(), deps)).status, 405);
});

test('relais : image vide ou trop grosse 413', async () => {
  const { cles, jeton } = await fabrique();
  const deps = { cles, maintenant: MAINTENANT };
  const t = await jeton();
  assert.equal((await traiter(requete({ jeton: t, corps: new Uint8Array(0) }), env(), deps)).status, 413);
  assert.equal((await traiter(requete({ jeton: t, corps: new Uint8Array(1_600_000) }), env(), deps)).status, 413);
});

test('relais : quota 429, et l\'IA n\'est pas appelée au-delà', async () => {
  const { cles, jeton } = await fabrique();
  const deps = { cles, maintenant: MAINTENANT };
  let appels = 0;
  const e = env(async () => (appels++, { response: '{"aliments":[]}' }));
  const t = await jeton();
  assert.equal((await traiter(requete({ jeton: t }), e, deps)).status, 200);
  assert.equal((await traiter(requete({ jeton: t }), e, deps)).status, 200);
  const r = await traiter(requete({ jeton: t }), e, deps);
  assert.equal(r.status, 429);
  assert.equal((await r.json()).erreur, 'quota');
  assert.equal(appels, 2);
});

test('relais : IA en panne 502, réponse illisible 422', async () => {
  const { cles, jeton } = await fabrique();
  const deps = { cles, maintenant: MAINTENANT };
  const t = await jeton();
  const panne = env(async () => {
    throw new Error('boom');
  });
  assert.equal((await traiter(requete({ jeton: t }), panne, deps)).status, 502);
  const charabia = env(async () => ({ response: 'désolé, je ne peux pas' }));
  assert.equal((await traiter(requete({ jeton: t }), charabia, deps)).status, 422);
});

const NUMERO = '123456789';

async function jetonAppCheck(charge = {}) {
  const { cles, jeton } = await fabrique();
  return {
    cles,
    jeton: await jeton({
      iss: `https://firebaseappcheck.googleapis.com/${NUMERO}`,
      aud: [`projects/${NUMERO}`, `projects/${PROJET}`],
      sub: '1:123456789:android:abc',
      ...charge,
    }),
  };
}

test('App Check : jeton valide, refus du mauvais projet, de l\'expiré', async () => {
  const options = (cles) => ({ projectId: PROJET, projectNumber: NUMERO, cles, maintenant: MAINTENANT });
  const bon = await jetonAppCheck();
  assert.equal(await verifierAppCheck(bon.jeton, options(bon.cles)), '1:123456789:android:abc');
  const autre = await jetonAppCheck({ iss: 'https://firebaseappcheck.googleapis.com/999' });
  await assert.rejects(verifierAppCheck(autre.jeton, options(autre.cles)), JetonInvalide);
  const aud = await jetonAppCheck({ aud: ['projects/999'] });
  await assert.rejects(verifierAppCheck(aud.jeton, options(aud.cles)), JetonInvalide);
  const vieux = await jetonAppCheck({ exp: MAINTENANT / 1000 - 1 });
  await assert.rejects(verifierAppCheck(vieux.jeton, options(vieux.cles)), JetonInvalide);
});

test('relais : App Check observe laisse passer, enforce refuse sans preuve', async () => {
  const { cles, jeton } = await fabrique();
  const preuve = await jetonAppCheck();
  const deps = { cles, clesAppCheck: preuve.cles, maintenant: MAINTENANT };
  const avec = (mode, enTete) => {
    const r = requete({ jeton: null });
    return new Request(r.url, {
      method: 'POST',
      headers: { authorization: `Bearer ${deps.jetonFirebase}`, ...enTete },
      body: JPEG,
    });
  };
  deps.jetonFirebase = await jeton();
  const e = (mode) => ({ ...env(), APP_CHECK: mode, PROJECT_NUMBER: NUMERO });

  assert.equal((await traiter(avec('off', {}), e('off'), deps)).status, 200);
  assert.equal((await traiter(avec('observe', {}), e('observe'), deps)).status, 200);
  assert.equal((await traiter(avec('enforce', {}), e('enforce'), deps)).status, 401);
  assert.equal(
    (await traiter(avec('enforce', { 'x-firebase-appcheck': 'faux' }), e('enforce'), deps)).status,
    401,
  );
  assert.equal(
    (await traiter(avec('enforce', { 'x-firebase-appcheck': preuve.jeton }), e('enforce'), deps)).status,
    200,
  );
});

const REPONSE_GEMINI = {
  candidates: [
    {
      content: {
        parts: [
          {
            text: '{"description":"Poulet au riz","aliments":[{"nom":"Riz","grammes":180,"kcal":234,"proteines":5,"glucides":50,"lipides":1,"confiance":0.8}]}',
          },
        ],
      },
      finishReason: 'STOP',
    },
  ],
};

function fauxFetch(reponses) {
  const appels = [];
  const f = async (url, init) => {
    appels.push({ url, init });
    const r = reponses.shift();
    if (r instanceof Error) throw r;
    return new Response(JSON.stringify(r.corps), { status: r.statut ?? 200 });
  };
  return { f, appels };
}

test('Gemini : la photo part avec la clé en en-tête, le résultat est nettoyé', async () => {
  const { cles, jeton } = await fabrique();
  const { f, appels } = fauxFetch([{ corps: REPONSE_GEMINI }]);
  let workersAppele = false;
  const e = { ...env(async () => { workersAppele = true; return { response: '{"aliments":[]}' }; }), GEMINI_API_KEY: 'cle-secrete' };
  const r = await traiter(
    new Request('https://relais.test/analyse?indice=' + encodeURIComponent('la moitié'), {
      method: 'POST',
      headers: { authorization: `Bearer ${await jeton()}` },
      body: JPEG,
    }),
    e,
    { cles, maintenant: MAINTENANT, fetcher: f },
  );
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.description, 'Poulet au riz');
  assert.equal(j.aliments[0].nom, 'Riz');
  assert.equal(workersAppele, false);
  assert.equal(appels.length, 1);
  assert.ok(appels[0].url.endsWith("/models/gemini-3.8-flash:generateContent"));
  assert.equal(appels[0].url.includes('cle-secrete'), false, 'cle dans adresse');
  assert.equal(appels[0].init.headers['x-goog-api-key'], 'cle-secrete');
  const corps = JSON.parse(appels[0].init.body);
  const parties = corps.contents[0].parts;
  assert.match(parties[0].text, /la moitié/);
  assert.equal(parties[1].inline_data.mime_type, 'image/jpeg');
  assert.equal(parties[1].inline_data.data, '/9j/4A==');
  assert.equal(corps.generationConfig.responseMimeType, 'application/json');
});

test('Gemini en panne, clé refusée ou réponse vide : repli sur Workers AI', async () => {
  const { cles, jeton } = await fabrique();
  for (const reponses of [
    [{ statut: 500, corps: {} }],
    [{ statut: 403, corps: { error: 'clé refusée' } }],
    [{ corps: { candidates: [] } }],
    [new Error('réseau')],
  ]) {
    const { f } = fauxFetch(reponses);
    const r = await traiter(
      requete({ jeton: await jeton() }),
      { ...env(), GEMINI_API_KEY: 'k' },
      { cles, maintenant: MAINTENANT, fetcher: f },
    );
    assert.equal(r.status, 200);
    assert.equal((await r.json()).aliments[0].nom, 'pomme');
  }
});

test('sans clé Gemini, ou FOURNISSEUR=workers : Workers AI directement', async () => {
  const { cles, jeton } = await fabrique();
  const { f, appels } = fauxFetch([{ corps: REPONSE_GEMINI }]);
  for (const e of [env(), { ...env(), GEMINI_API_KEY: 'k', FOURNISSEUR: 'workers' }]) {
    const r = await traiter(requete({ jeton: await jeton() }), e, { cles, maintenant: MAINTENANT, fetcher: f });
    assert.equal((await r.json()).aliments[0].nom, 'pomme');
  }
  assert.equal(appels.length, 0);
});

test('modèle principal illisible ou en panne : le modèle de secours répond', async () => {
  const { cles, jeton } = await fabrique();
  const appels = [];
  const ia = async (modele) => {
    appels.push(modele);
    if (modele === 'principal') return { response: '**Description :** du texte libre, pas du JSON' };
    return { response: '{"aliments":[{"nom":"pomme","grammes":150,"kcal":78}]}' };
  };
  const e = { ...env(ia), MODELE: 'principal', MODELE_SECOURS: 'secours' };
  const r = await traiter(requete({ jeton: await jeton() }), e, { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 200);
  assert.equal((await r.json()).aliments[0].nom, 'pomme');
  assert.deepEqual(appels, ['principal', 'secours']);

  // Principal en panne : même chose.
  appels.length = 0;
  const panne = async (modele) => {
    appels.push(modele);
    if (modele === 'principal') throw new Error('panne');
    return { response: '{"aliments":[{"nom":"poire","grammes":120,"kcal":70}]}' };
  };
  const r2 = await traiter(requete({ jeton: await jeton() }), { ...env(panne), MODELE: 'principal', MODELE_SECOURS: 'secours' }, { cles, maintenant: MAINTENANT });
  assert.equal((await r2.json()).aliments[0].nom, 'poire');

  // Principal valide : le secours n'est pas appelé.
  appels.length = 0;
  const bon = async (modele) => { appels.push(modele); return { response: '{"aliments":[]}' }; };
  await traiter(requete({ jeton: await jeton() }), { ...env(bon), MODELE: 'principal', MODELE_SECOURS: 'secours' }, { cles, maintenant: MAINTENANT });
  assert.deepEqual(appels, ['principal']);
});

test('texte libre (puces) : la réponse de Llama 3.2 est récupérée', () => {
  const texte = [
    '**Description :** Plat de poisson grillé sur un lit de cuscus.',
    '',
    '**Aliments :**',
    '',
    '*   Poisson (halibut ou saumon) : 200 g',
    '    *   Kcal : 180',
    '    *   Protéines : 30 g',
    '    *   Glucides : 0 g',
    '    *   Sucres : 0 g',
    '    *   Lipides : 6 g',
    '    *   Satures : 1 g',
    '    *   Confiance : 1',
    '*   Cuscus : 100 g',
    '    *   Kcal : 150',
    '    *   Protéines : 3 g',
    '    *   Glucides : 30 g',
    '    *   Lipides : 1 g',
    '    *   Confiance : 0,7',
  ].join('\n');
  const r = analyse(texte);
  assert.equal(r.description, 'Plat de poisson grillé sur un lit de cuscus.');
  assert.equal(r.aliments.length, 2);
  const [poisson, cuscus] = r.aliments;
  assert.equal(poisson.nom, 'Poisson (halibut ou saumon)');
  assert.equal(poisson.grammes, 200);
  assert.equal(poisson.proteines, 30);
  assert.equal(poisson.lipides, 6);
  assert.equal(poisson.satures, 1);
  assert.equal(cuscus.glucides, 30);
  assert.equal(cuscus.confiance, 0.7);
  // Du JSON reste du JSON, et un texte sans aliment ne donne rien.
  assert.equal(analyse('{"aliments":[{"nom":"x","grammes":10,"kcal":5}]}').aliments[0].nom, 'x');
  assert.equal(analyse('Je ne vois aucun plat sur cette image.'), null);
});

test('fourchette de quantité : gardée si elle encadre l\'estimation', () => {
  const r = analyse({
    aliments: [
      { nom: 'riz', grammes: 200, grammes_min: 150, grammes_max: 260, kcal: 260 },
      { nom: 'incohérent', grammes: 100, grammes_min: 150, grammes_max: 200, kcal: 100 },
      { nom: 'énorme', grammes: 100, grammes_min: 50, grammes_max: 2000, kcal: 100 },
      { nom: 'sans', grammes: 80, kcal: 100 },
    ],
  });
  assert.deepEqual([r.aliments[0].grammes_min, r.aliments[0].grammes_max], [150, 260]);
  assert.equal(r.aliments[1].grammes_min, undefined);
  assert.equal(r.aliments[2].grammes_max, undefined);
  assert.equal(r.aliments[3].grammes_min, undefined);
});

test('Llama 3.2 : JSON sans accolades, clés capitalisées, réponse coupée', () => {
  const coupe = [
    '"Description": "Plat de riz, haricots rouges et légumes.",',
    '"Aliments": [',
    '{"Nom": "Riz", "Grammes": 150, "Grammes_min": 100, "Grammes_max": 200, "Kcal": 360, "Proteines": 6, "Glucides": 70, "Sucres": 0, "Lipides": 2, "Satures": 0, "Confiance": 0.8},',
    '{"Nom": "Haricots rouges", "Grammes": 200, "Grammes_min": 150, "Grammes_max": 250, "Kcal": 150, "Proteines": 10, "Glucides": 30, "Sucres": 0, "Lipides": 0, "Satures": 0, "Confiance": 0.8},',
    '{"Nom": "Huile d\'olive", "Grammes": 10, "Grammes_min": 5, "Grammes_max": 15, "Kcal": 90, "Proteines": 0, "Glucides": 0, "Sucres": 0, "Lipides": 10, "Satures": 1, "Confianc',
  ].join('\n');
  const r = analyse(coupe);
  assert.equal(r.description, 'Plat de riz, haricots rouges et légumes.');
  assert.deepEqual(r.aliments.map((a) => a.nom), ['Riz', 'Haricots rouges']);
  assert.equal(r.aliments[0].grammes, 150);
  assert.equal(r.aliments[0].grammes_min, 100);
  assert.equal(r.aliments[0].grammes_max, 200);
  assert.equal(r.aliments[0].proteines, 4.1); // riz à 2,4 kcal/g annoncé : recalculé avec le repère (1,3 kcal/g)

  // Complète, avec des accolades manquantes seulement autour.
  const complete = '"Description": "x", "Aliments": [{"Nom": "Pomme", "Grammes": 120, "Kcal": 62}]';
  assert.equal(analyse(complete).aliments[0].nom, 'Pomme');

  // Du JSON normal avec des clés accentuées ou capitalisées.
  const normal = analyse('{"Description":"y","aliments":[{"nom":"Kiwi","grammes":100,"kcal":57,"Protéines":0.4}]}');
  assert.equal(normal.aliments[0].proteines, 0.4);
});

import { referentiel } from '../src/referentiel.js';

test('référentiel : aliments sûrs reconnus, plats composés et crus écartés', () => {
  assert.equal(referentiel('Riz').kcal, 130);
  assert.equal(referentiel('Poisson (halibut ou saumon)'), null);
  assert.equal(referentiel('Saumon').kcal, 206);
  assert.equal(referentiel('Blanc de poulet grillé').kcal, 165);
  assert.equal(referentiel('Spaghettis').kcal, 158);
  assert.equal(referentiel('Pommes de terre').kcal, 86);
  assert.equal(referentiel('Frites').kcal, 300);
  assert.equal(referentiel('Riz au lait'), null);
  assert.equal(referentiel('Sauce tomate'), null);
  assert.equal(referentiel('Poulet et riz'), null);
  assert.equal(referentiel('Salade composée'), null);
  assert.equal(referentiel('Pomme').kcal, 52);
  // Pommes de terre sautées : environ 150 kcal pour 100 g, pas les 86 de la vapeur.
  assert.equal(referentiel('Pomme de terre sautée'), null);
  assert.equal(referentiel('Pommes de terre sautées'), null);
  assert.equal(referentiel('Pommes de terre vapeur').kcal, 86);
  assert.equal(referentiel('Chocolat'), null);
  assert.equal(referentiel(''), null);
  assert.equal(referentiel(undefined), null);
});

test('un aliment connu à la densité absurde est recalculé, un plausible est laissé', () => {
  const r = analyse({
    aliments: [
      // Riz cuit annoncé à 0,5 kcal/g (le tableau dit 1,3) : corrigé.
      { nom: 'Riz', grammes: 200, kcal: 100, proteines: 2, glucides: 20, lipides: 2, confiance: 1 },
      // Riz dans la bonne fourchette (1,2 kcal/g) : inchangé.
      { nom: 'Riz', grammes: 200, kcal: 240, proteines: 5, glucides: 52, lipides: 0.6 },
      // Aliment inconnu : inchangé même s'il paraît faible.
      { nom: 'Plat mystère', grammes: 200, kcal: 100, proteines: 2, glucides: 20, lipides: 2 },
    ],
  });
  const [corrige, plausible, inconnu] = r.aliments;
  assert.equal(corrige.kcal, 260);
  assert.equal(corrige.proteines, 5.4);
  assert.equal(corrige.glucides, 56);
  assert.equal(corrige.grammes, 200);
  assert.equal(plausible.kcal, 240);
  assert.equal(plausible.glucides, 52);
  assert.equal(inconnu.kcal, 100);
});

test('référentiel : liste blanche stricte, variantes et plats jamais corrigés', () => {
  for (const nom of [
    'Escalope de poulet panée',
    'Aiguillettes de poulet panées',
    'Filets de colin panés',
    'Yaourt à la grecque',
    'Jambon cru',
    'Jambon de Bayonne',
    'Pain au chocolat',
    'Pain aux raisins',
    "Porridge d'avoine",
    'Avoine cuite',
    'Salade niçoise',
    'Salade de chèvre chaud',
    'Steak de thon',
    "Thon à l'huile",
    'Crevettes frites',
    'Ailes de poulet frites',
    'Riz cantonais',
    'Riz frit',
    'Spaghetti carbonara',
    'Omelette au fromage',
    'Poulet rôti aux herbes',
  ]) {
    assert.equal(referentiel(nom), null, nom);
  }
  // Adjectifs neutres retirés : le nom reste celui d'un aliment simple.
  assert.equal(referentiel('Riz blanc').kcal, 130);
  assert.equal(referentiel("Riz cuit à l'eau").kcal, 130);
  assert.equal(referentiel('Fromage blanc').kcal, 60);
  assert.equal(referentiel('Yaourt nature').kcal, 55);
  assert.equal(referentiel('Flocons d’avoine').kcal, 370);
});

test('référentiel : la ligature « œ » est reconnue', () => {
  assert.equal(referentiel('Œuf').kcal, 143);
  assert.equal(referentiel('Œufs').kcal, 143);
  assert.equal(referentiel('Bœuf').kcal, 220);
  assert.equal(referentiel('Œufs brouillés'), null);
});

test('aliments : des valeurs justes ne sont plus remplacées par celles d\'un autre aliment', () => {
  const r = analyse({
    aliments: [
      { nom: 'Pain au chocolat', grammes: 60, kcal: 250, proteines: 4.5, glucides: 27, lipides: 14, confiance: 0.8 },
      { nom: "Porridge d'avoine", grammes: 250, kcal: 225, proteines: 8, glucides: 35, lipides: 5, confiance: 0.8 },
      { nom: 'Pommes de terre sautées', grammes: 200, kcal: 300, proteines: 4, glucides: 40, lipides: 14, confiance: 0.8 },
      { nom: 'Yaourt à la grecque', grammes: 150, kcal: 180, proteines: 9, glucides: 6, lipides: 13.5, confiance: 0.8 },
    ],
  });
  assert.deepEqual(
    r.aliments.map((a) => a.kcal),
    [250, 225, 300, 180],
  );
  assert.equal(r.aliments[0].lipides, 14);
});

test("alcool : les calories d'une bière ou d'un verre de vin sont gardées", () => {
  const r = analyse({
    aliments: [
      // Sans le champ "alcool" : le nom suffit à garder les kcal.
      { nom: 'Bière blonde', grammes: 330, kcal: 140, glucides: 12, proteines: 1.5, confiance: 0.8 },
      { nom: 'Vin rouge', grammes: 125, kcal: 85, glucides: 3, confiance: 0.8 },
      // Avec le champ "alcool" : 7 kcal par gramme comptés dans les macros.
      { nom: 'Pinte', grammes: 500, kcal: 215, glucides: 18, proteines: 2, alcool: 20, confiance: 0.8 },
      // Une boisson sans alcool reste corrigée par ses macros.
      { nom: 'Jus de pomme', grammes: 200, kcal: 300, glucides: 20, confiance: 0.8 },
    ],
  });
  const [biere, vin, pinte, jus] = r.aliments;
  assert.equal(biere.kcal, 140);
  assert.equal(vin.kcal, 85);
  assert.equal(pinte.kcal, 215); // 2×4 + 18×4 + 20×7 = 220 : à moins de 25 %
  assert.equal(jus.kcal, 80);
  assert.ok(CONSIGNE.includes('"alcool"'));
});

test("étiquette d'un produit emballé : le référentiel ne remplace pas ses valeurs", () => {
  const r = analyse({
    description: 'Riz basmati, sachet de 1 kg',
    aliments: [
      { nom: 'Riz basmati', grammes: 1000, kcal: 3500, proteines: 80, glucides: 770, lipides: 10, source: 'etiquette' },
      { nom: 'Riz', grammes: 1000, kcal: 3500, proteines: 80, glucides: 770, lipides: 10, source: 'Étiquette' },
      // Mêmes valeurs, estimées : le riz cuit du tableau s'applique.
      { nom: 'Riz', grammes: 1000, kcal: 3500, proteines: 80, glucides: 770, lipides: 10, source: 'estimation' },
    ],
  });
  const [basmati, etiquette, estimation] = r.aliments;
  assert.equal(basmati.kcal, 3000); // bornée à 3000 kcal, pas ramenée à 1300
  assert.equal(etiquette.glucides, 770);
  assert.equal(estimation.kcal, 1300);
  assert.ok(CONSIGNE.includes('"source"'));
});

test('texte libre : fibres, récapitulatif « Total » et poids total ignorés', () => {
  const texte = [
    '**Description :** Riz et poulet rôti.',
    '',
    '*   Riz : 180 g',
    '    *   Kcal : 234',
    '*   Poulet rôti : 150 g',
    '    *   Kcal : 300',
    '    *   Protéines : 40 g',
    '    *   Lipides : 15,5 g',
    '    *   Fibres : 3 g',
    '    *   Acides gras saturés : 4 g',
    '*   Poids total : 330 g',
    '',
    '**Total :**',
    '',
    '*   Kcal : 534',
    '*   Protéines : 45 g',
    '*   Glucides : 50 g',
  ].join('\n');
  const r = analyse(texte);
  assert.deepEqual(r.aliments.map((a) => a.nom), ['Riz', 'Poulet rôti']);
  assert.equal(r.aliments.reduce((t, a) => t + a.kcal, 0), 534);
  assert.equal(r.aliments[1].proteines, 40);

  // « Poids total » n'est pas un aliment.
  assert.deepEqual(depuisTexteLibre('*   Poids total : 330 g\n*   Pomme : 150 g').aliments.map((a) => a.nom), ['Pomme']);
  // Une macro au même niveau que l'aliment ne lui est pas rattachée.
  assert.equal(depuisTexteLibre('* Pomme : 150 g\n* Kcal : 900').aliments[0].kcal, undefined);
});

test('aliment sans calories ni macros : signalé « à vérifier », ou réponse illisible', () => {
  // Seul aliment, sans aucune valeur : rien d'exploitable (422, ou modèle de secours).
  assert.equal(analyse({ aliments: [{ nom: 'Plat du jour', grammes: 250 }] }), null);
  assert.equal(analyse('*   Plat du jour : 250 g'), null);
  // Aliment d'une table : ses valeurs servent de repère, toujours « à vérifier ».
  const connu = analyse({ aliments: [{ nom: 'Gratin dauphinois', grammes: 250 }] }).aliments[0];
  assert.equal(connu.kcal, 273);
  assert.equal(connu.reference, 'Gratin dauphinois');
  assert.equal(connu.confiance, 0.3);
  // À côté d'un aliment chiffré : gardé, mais à 0,3 de confiance au plus.
  const r = analyse({
    aliments: [
      { nom: 'Plat du jour', grammes: 250, confiance: 0.9 },
      { nom: 'Steak', grammes: 150, kcal: 330, proteines: 40, lipides: 18, confiance: 0.9 },
    ],
  });
  assert.equal(r.aliments[0].kcal, 0);
  assert.equal(r.aliments[0].confiance, 0.3);
  assert.equal(r.aliments[1].confiance, 0.9);
  // Une boisson à 0 kcal annoncée par le modèle reste une réponse valable.
  assert.equal(analyse({ aliments: [{ nom: 'Eau', grammes: 250, kcal: 0, confiance: 0.9 }] }).aliments[0].kcal, 0);
});

test('relais : une réponse sans aucune calorie donne 422 (illisible)', async () => {
  const { cles, jeton } = await fabrique();
  const vide = env(async () => ({ response: '{"aliments":[{"nom":"Plat du jour","grammes":250}]}' }));
  const r = await traiter(requete({ jeton: await jeton() }), vide, { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 422);
  assert.equal((await r.json()).erreur, 'illisible');
});
