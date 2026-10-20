import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, expect, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

// Documents réellement écrits par l'application et par l'import Excel,
// générés par app/test/regles_fixtures_test.dart (flutter test).
const fixtures = JSON.parse(
  readFileSync(new URL('./fixtures/documents.json', import.meta.url), 'utf8'),
);

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-coach',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

afterAll(async () => {
  await env.cleanup();
});

const alice = () => env.authenticatedContext('alice').firestore();

const repas = (plus = {}) => ({
  date: 1760000000000,
  moment: 'dejeuner',
  nom: 'Riz',
  macros: { kcal: 130, proteines: 3, glucides: 28, lipides: 0 },
  source: 'photo',
  ...plus,
});

const eau = { date: 1760000000000, ml: 250 };

test('alice lit et écrit son propre document', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { a: 1 }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
});

test('alice lit et écrit ses collections', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/eau/e1'), eau));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/eau/e1')));
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice/reglages/bienetre'), { meteo: true }),
  );
});

test('une collection inconnue est refusée', async () => {
  await assertFails(setDoc(doc(alice(), 'users/alice/meals/m1'), { a: 1 }));
});

test('un document énorme est refusé', async () => {
  const gros = Object.fromEntries(Array.from({ length: 100 }, (_, i) => [`c${i}`, i]));
  await assertFails(setDoc(doc(alice(), 'users/alice/eau/e1'), gros));
});

test('un repas valide est accepté, avec analyse et verdict', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/repas/r1'), repas()));
  await assertSucceeds(
    setDoc(
      doc(alice(), 'users/alice/repas/r2'),
      repas({
        description: 'Du riz',
        aliments: [{ nom: 'Riz', grammes: 100 }],
        photoId: '1760000000000000',
        verdict: { feu: 'vert', points: ['ok'], conclusion: 'bien' },
      }),
    ),
  );
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/repas/r1')));
});

test('un repas mal formé est refusé', async () => {
  const ref = (id) => doc(alice(), `users/alice/repas/${id}`);
  await assertFails(setDoc(ref('a'), repas({ nom: 'x'.repeat(401) })));
  await assertFails(setDoc(ref('b'), repas({ date: 'hier' })));
  await assertFails(setDoc(ref('c'), repas({ intrus: 1 })));
  await assertFails(setDoc(ref('d'), repas({ macros: 'beaucoup' })));
  await assertFails(
    setDoc(ref('e'), repas({ aliments: Array.from({ length: 41 }, () => ({})) })),
  );
  await assertFails(setDoc(ref('f'), { nom: 'sans le reste' }));
  await assertFails(setDoc(ref('g'), repas({ description: 'x'.repeat(801) })));
  await assertFails(setDoc(ref('h'), repas({ photoId: '1'.repeat(31) })));
  await assertFails(setDoc(ref('i'), repas({ moment: 'x'.repeat(21) })));
});

test('alice ne lit pas les données de bob', async () => {
  await assertFails(getDoc(doc(alice(), 'users/bob')));
  await assertFails(getDoc(doc(alice(), 'users/bob/eau/e1')));
});

test('alice n\'écrit pas chez bob', async () => {
  await assertFails(setDoc(doc(alice(), 'users/bob/eau/e1'), eau));
  await assertFails(setDoc(doc(alice(), 'users/bob/repas/r1'), repas()));
});

test('un visiteur non connecté ne lit rien', async () => {
  const anonyme = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonyme, 'users/alice')));
});

test('alice n\'écrit pas hors de users', async () => {
  await assertFails(setDoc(doc(alice(), 'autre/x'), { a: 1 }));
});

test('les fixtures couvrent les 11 collections', () => {
  const collections = new Set(fixtures.map((f) => f.chemin.split('/')[0]));
  expect(collections.size).toBe(11);
});

test.each(fixtures.map((f) => [f.chemin, f.donnees]))(
  'document écrit par l\'appli accepté : %s',
  async (chemin, donnees) => {
    await assertSucceeds(setDoc(doc(alice(), `users/alice/${chemin}`), donnees));
  },
);

test('une sous-collection imbriquée est refusée, même sous une collection connue', async () => {
  await assertFails(setDoc(doc(alice(), 'users/alice/eau/a/b/c'), eau));
  await assertFails(setDoc(doc(alice(), 'users/alice/reglages/x/y/z'), { meteo: true }));
  await assertFails(getDoc(doc(alice(), 'users/alice/eau/a/b/c')));
});

// Pour chaque collection : un document valide, puis des variantes refusées.
const valides = {
  activites: { date: 1, type: 'course', minutes: 30, intensite: 'moderee', kcal: 300 },
  pesees: { kg: 80, date: 1, source: 'manuel' },
  mensurations: { date: 1, taille: 80 },
  eau: { date: 1, ml: 250 },
  complements: { nom: 'Zinc', minutes: 480, actif: true },
  prises: { ids: ['c1'] },
  seances: { date: 1, lieu: 'maison', minutes: 40 },
  ressentis: { valeur: 2 },
  planning: { vegetarien: false, coches: [], repas: {} },
};

const invalides = {
  activites: [
    { minutes: 5000 },
    { kcal: -1 },
    { type: 'x'.repeat(21) },
    { intrus: 1 },
  ],
  pesees: [{ kg: 5 }, { kg: 900 }, { kg: '80' }, { source: 'x'.repeat(21) }],
  mensurations: [{ taille: 400 }, { masseGrasse: 150 }, { cou: 30 }, { date: 'hier' }],
  eau: [{ ml: 0 }, { ml: 6000 }, { ml: 'beaucoup' }, { note: 'x' }],
  complements: [
    { nom: 'x'.repeat(81) },
    { minutes: 1440 },
    { actif: 'oui' },
    { dose: '5 g' },
  ],
  prises: [{ ids: Array.from({ length: 51 }, (_, i) => `c${i}`) }, { ids: 'c1' }],
  seances: [{ minutes: 0 }, { minutes: 601 }, { lieu: 3 }, { exos: [] }],
  ressentis: [{ valeur: 0 }, { valeur: 4 }, { valeur: 'bien' }],
  planning: [
    { vegetarien: 'oui' },
    { coches: Array.from({ length: 501 }, (_, i) => `a${i}`) },
    { repas: 'lundi' },
    { notes: 'x' },
  ],
};

test.each(Object.entries(valides))('%s : un document valide est accepté', async (col, d) => {
  await assertSucceeds(setDoc(doc(alice(), `users/alice/${col}/ok`), d));
});

test.each(
  Object.entries(invalides).flatMap(([col, cas]) =>
    cas.map((plus) => [col, JSON.stringify(plus).slice(0, 40), plus]),
  ),
)('%s : document invalide refusé (%s)', async (col, _, plus) => {
  await assertFails(
    setDoc(doc(alice(), `users/alice/${col}/ko`), { ...valides[col], ...plus }),
  );
});

test('un champ obligatoire manquant est refusé', async () => {
  const ref = (chemin) => doc(alice(), `users/alice/${chemin}`);
  await assertFails(setDoc(ref('eau/a'), { ml: 250 }));
  await assertFails(setDoc(ref('complements/a'), { nom: 'Zinc' }));
  await assertFails(setDoc(ref('seances/a'), { date: 1, minutes: 30 }));
  await assertFails(setDoc(ref('pesees/a'), { date: 1 }));
  await assertFails(setDoc(ref('ressentis/a'), {}));
});

test('réglages : seuls les quatre documents connus, avec leurs champs', async () => {
  const r = (id) => doc(alice(), `users/alice/reglages/${id}`);
  await assertSucceeds(setDoc(r('consentements'), { photo: 1760000000000 }));
  await assertSucceeds(setDoc(r('bienetre'), { meteo: true }));
  await assertSucceeds(setDoc(r('entrainement'), { materiel: ['halteres'] }));
  await assertSucceeds(setDoc(r('recettes'), { avis: { r1: 'aime' } }));

  await assertFails(setDoc(r('autre'), { meteo: true }));
  await assertFails(setDoc(r('consentements'), { photo: 'oui' }));
  await assertFails(setDoc(r('consentements'), { photo: 1, admin: 1 }));
  await assertFails(setDoc(r('bienetre'), { meteo: 'oui' }));
  await assertFails(setDoc(r('entrainement'), { materiel: 'halteres' }));
  await assertFails(setDoc(r('recettes'), { avis: 'aime' }));
});
