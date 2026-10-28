import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ciqual } from '../src/ciqual.js';
import { analyse } from '../src/analyse.js';

test('Ciqual : aliments précis reconnus, forme mangée par défaut', () => {
  assert.equal(ciqual('Riz basmati').reference, 'Riz basmati, cuit, non salé');
  assert.equal(ciqual('Riz').reference, 'Riz blanc, cuit, non salé');
  assert.equal(ciqual('Saumon grillé').reference, 'Saumon, grillé/poêlé');
  assert.equal(ciqual('Quiche lorraine').kcal, 274);
  assert.equal(ciqual('Pain').reference, 'Pain (aliment moyen)');
  // Un fruit se mange cru, un café se boit.
  assert.equal(ciqual('Banane').reference, 'Banane, pulpe, crue');
  assert.equal(ciqual('Café').reference, 'Café, non instantané, non sucré, prêt à boire');
  assert.equal(ciqual('Thé').kcal, 0);
  // Pluriels, accents, ligatures et précisions entre parenthèses.
  assert.equal(ciqual('Œufs durs').reference, 'Oeuf, dur');
  assert.equal(ciqual('fraises (gariguettes)').reference, 'Fraise, crue');
});

test('Ciqual : dans le doute, rien plutôt qu\'un autre aliment', () => {
  // Pâtes et pâté, une fois les accents retirés, s'écrivent pareil.
  assert.notEqual(ciqual('Pâtes').reference, 'Pâté (aliment moyen)');
  assert.match(ciqual('Pâté').reference, /^Pâté/);
  // Autre variété ou autre plat : pas de rapprochement.
  assert.equal(ciqual('Yaourt'), null); // nature, grec, aux fruits ?
  assert.equal(ciqual('Poulet'), null); // filet ou cuisse ?
  assert.equal(ciqual('Burger'), null); // seul « Burger au poulet » existe
  assert.equal(ciqual('Glace'), null); // pas « Glace à l'eau »
  assert.equal(ciqual('Jambon'), null); // pas « Jambon de poulet »
  assert.equal(ciqual('Pommes de terre sautées'), null);
  assert.equal(ciqual('Spécialité du chef'), null);
  assert.equal(ciqual(''), null);
  assert.equal(ciqual(undefined), null);
});

test('Ciqual : corrige une densité absurde et le signale, laisse une valeur plausible', () => {
  const r = analyse({
    aliments: [
      // 300 g de quiche à 120 kcal : bien trop peu (274 kcal pour 100 g).
      { nom: 'Quiche lorraine', grammes: 300, kcal: 120, proteines: 5, glucides: 10, lipides: 5, confiance: 0.8 },
      // Plausible : gardé tel quel.
      { nom: 'Riz basmati', grammes: 150, kcal: 180, proteines: 4, glucides: 39, lipides: 0.6, confiance: 0.8 },
    ],
  });
  const [quiche, riz] = r.aliments;
  assert.equal(quiche.grammes, 300);
  assert.equal(quiche.kcal, 822);
  assert.equal(quiche.reference, 'Quiche lorraine, préemballée');
  assert.equal(riz.kcal, 180);
  assert.equal(riz.reference, undefined);
});

test('Ciqual : jamais pour une étiquette ni pour un produit à la recette particulière', () => {
  const quiche = { nom: 'Quiche lorraine', grammes: 100, kcal: 150, proteines: 10, glucides: 15, lipides: 5.5, confiance: 0.9 };
  assert.equal(analyse({ aliments: [{ ...quiche, source: 'etiquette' }] }).aliments[0].kcal, 150);
  assert.equal(analyse({ description: 'Quiche lorraine allégée Marque', aliments: [quiche] }).aliments[0].kcal, 150);
  assert.equal(analyse({ description: 'Quiche', aliments: [quiche] }).aliments[0].kcal, 274);
});

test('Ciqual : aliments courants à correspondance choisie à la main', () => {
  assert.equal(ciqual('Frites').kcal, 285);
  assert.equal(ciqual("Huile d'olive").kcal, 900);
  assert.equal(ciqual('Baguette').reference, 'Pain, baguette, courante');
  assert.equal(ciqual('Jambon blanc').reference, 'Jambon cuit, supérieur');
  assert.equal(ciqual('Poulet rôti').reference, 'Poulet, viande et peau, rôti/cuit au four');
  assert.equal(ciqual('Haricots verts').reference, 'Haricot vert, cuit');
  assert.equal(ciqual('Noix').kcal, 686);
  assert.equal(ciqual('Spaghettis').reference, 'Pâtes sèches standard, cuites, non salées');
  // Le nom entier seulement : le reste garde la prudence habituelle.
  assert.equal(ciqual('Poulet'), null);
  assert.equal(ciqual('Frites de patate douce'), null);
});
