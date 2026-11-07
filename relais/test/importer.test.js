import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lirePlats, melanger } from '../eval/importer_nutrition5k.mjs';

test('lirePlats garde les plats réalistes et écarte les aberrants', () => {
  const csv = [
    'dish_1561662216,300.5,250.2,10,20,30,ingr_1',
    'dish_1,5,250,1,1,1',
    'dish_2,400,5000,1,1,1',
    'pas_un_plat,400,300',
  ].join('\n');
  assert.deepEqual(lirePlats(csv), [{ id: 'dish_1561662216', kcal: 301, grammes: 250 }]);
});

test('melanger est reproductible', () => {
  const l = [1, 2, 3, 4, 5, 6, 7, 8];
  assert.deepEqual(melanger(l, 1), melanger(l, 1));
  assert.equal(melanger(l, 1).length, 8);
});
