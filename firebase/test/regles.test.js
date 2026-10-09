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

test('alice lit et écrit son propre document', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { a: 1 }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
});

test('alice lit et écrit ses sous-collections', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/meals/m1'), { a: 1 }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/meals/m1')));
});

test('alice ne lit pas les données de bob', async () => {
  await assertFails(getDoc(doc(alice(), 'users/bob')));
});

test('alice n\'écrit pas chez bob', async () => {
  await assertFails(setDoc(doc(alice(), 'users/bob/meals/m1'), { a: 1 }));
});

test('un visiteur non connecté ne lit rien', async () => {
  const anonyme = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anonyme, 'users/alice')));
});

test('alice n\'écrit pas hors de users', async () => {
  await assertFails(setDoc(doc(alice(), 'autre/x'), { a: 1 }));
});
