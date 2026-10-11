import assert from 'node:assert/strict';
import { test } from 'node:test';

import { aliments, analyse, entreeModele, extraireJson, nettoyerIndice } from '../src/analyse.js';
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

test('aliments : confiance bornée, 0,7 par défaut', () => {
  const l = aliments({
    aliments: [
      { nom: 'a', grammes: 10, kcal: 10, confiance: 3 },
      { nom: 'b', grammes: 10, kcal: 10, confiance: -1 },
      { nom: 'c', grammes: 10, kcal: 10 },
      { nom: 'd', grammes: 10, kcal: 10, confiance: '0.4' },
    ],
  });
  assert.deepEqual(l.map((x) => x.confiance), [1, 0, 0.7, 0.4]);
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

function requete({ jeton, corps = new Uint8Array([1, 2, 3]), methode = 'POST', chemin = '/analyse' } = {}) {
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
      body: new Uint8Array([1, 2, 3]),
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
