import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

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

test('alice lit et écrit son propre document', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { a: 1 }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
});

test('alice lit et écrit ses collections', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/eau/e1'), { ml: 250 }));
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
  await assertFails(setDoc(ref('a'), repas({ nom: 'x'.repeat(500) })));
  await assertFails(setDoc(ref('b'), repas({ date: 'hier' })));
  await assertFails(setDoc(ref('c'), repas({ intrus: 1 })));
  await assertFails(setDoc(ref('d'), repas({ macros: 'beaucoup' })));
  await assertFails(
    setDoc(ref('e'), repas({ aliments: Array.from({ length: 41 }, () => ({})) })),
  );
  await assertFails(setDoc(ref('f'), { nom: 'sans le reste' }));
});

test('alice ne lit pas les données de bob', async () => {
  await assertFails(getDoc(doc(alice(), 'users/bob')));
});

test('alice n\'écrit pas chez bob', async () => {
  await assertFails(setDoc(doc(alice(), 'users/bob/eau/e1'), { ml: 250 }));
  await assertFails(setDoc(doc(alice(), 'users/bob/repas/r1'), repas()));
});

test('un visiteur non connecté ne lit rien', async () => {
  const anonyme = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonyme, 'users/alice')));
});

test('alice n\'écrit pas hors de users', async () => {
  await assertFails(setDoc(doc(alice(), 'autre/x'), { a: 1 }));
});
