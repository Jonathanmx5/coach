import assert from 'node:assert/strict';
import { test } from 'node:test';

import { dansLaFourchette, ecartRelatif, pourcent, resumer } from '../eval/metriques.js';

test('écart relatif : valeurs normales et références absurdes', () => {
  assert.ok(Math.abs(ecartRelatif(550, 500) - 0.1) < 1e-9);
  assert.ok(Math.abs(ecartRelatif(450, 500) - 0.1) < 1e-9);
  assert.equal(ecartRelatif(100, 0), null);
  assert.equal(ecartRelatif(NaN, 500), null);
});

test('résumé : lisibilité, erreur médiane, ±20 %, fourchette', () => {
  const r = resumer([
    { ok: true, kcalEstime: 520, kcalRef: 500, grammesEstime: 300, grammesRef: 320, dansFourchette: true, ms: 8000 },
    { ok: true, kcalEstime: 700, kcalRef: 500, grammesEstime: 500, grammesRef: 400, dansFourchette: false, ms: 10000 },
    { ok: true, kcalEstime: 480, kcalRef: 600, grammesEstime: 350, grammesRef: 350, dansFourchette: true, ms: 12000 },
    { ok: false, ms: 5000 },
  ]);
  assert.equal(r.photos, 4);
  assert.equal(r.lisibles, 3);
  assert.equal(r.tauxLisible, 0.75);
  // écarts : 4 %, 40 %, 20 % : médiane 20 %
  assert.ok(Math.abs(r.ecartKcalMedian - 0.2) < 1e-9);
  assert.ok(Math.abs(r.dans20pc - 2 / 3) < 1e-9);
  assert.ok(Math.abs(r.fourchetteJuste - 2 / 3) < 1e-9);
  assert.equal(Math.round(r.dureeMoyenneMs), 8750);
  assert.equal(resumer([]).tauxLisible, 0);
  assert.equal(resumer([{ ok: false }]).ecartKcalMedian, null);
});

test('fourchette : somme des minimums et des maximums des aliments', () => {
  const aliments = [{ grammes: 200, grammes_min: 150, grammes_max: 250 }, { grammes: 100 }];
  assert.equal(dansLaFourchette(aliments, 270), true);
  assert.equal(dansLaFourchette(aliments, 240), false);
  assert.equal(pourcent(0.456), '46 %');
  assert.equal(pourcent(null), '—');
});
