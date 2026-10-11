import assert from 'node:assert/strict';
import { test } from 'node:test';

import { aliments, extraireJson } from '../src/analyse.js';
import { traiter } from '../src/index.js';
import { JetonInvalide, verifierJeton } from '../src/jeton.js';
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

test('relais : parcours complet', async () => {
  const { cles, jeton } = await fabrique();
  const r = await traiter(requete({ jeton: await jeton() }), env(), { cles, maintenant: MAINTENANT });
  assert.equal(r.status, 200);
  const j = await r.json();
  assert.equal(j.aliments[0].nom, 'pomme');
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
