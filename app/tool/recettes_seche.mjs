// Génère lib/recettes/recettes_seche.dart : des recettes pour une sèche
// (beaucoup de protéines, peu de calories), dont les apports sont CALCULÉS à
// partir de la table Ciqual 2020 de l'ANSES (assets/ciqual.json, CC BY 4.0)
// et non estimés à la main. Chaque ingrédient renvoie à un code Ciqual et à
// son poids en grammes pour une portion.
// Usage : node tool/recettes_seche.mjs   (puis dart format lib/recettes)
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = join(dirname(fileURLToPath(import.meta.url)), '..');
const ciqual = JSON.parse(readFileSync(join(ici, 'assets', 'ciqual.json'), 'utf8'));
const col = Object.fromEntries(ciqual.colonnes.map((c, i) => [c, i]));
const parCode = new Map(ciqual.aliments.map((a) => [a[col.code], a]));

// [nom affiché, quantité, unité (g, ml, piece), rayon, code Ciqual, grammes]
// « grammes » : poids total de l'ingrédient pour une portion.
const FL = 'fl', BO = 'bo', VP = 'vp', CR = 'cr', EP = 'ep';
const g = (nom, q, rayon, code) => [nom, q, 'g', rayon, code, q];
const ml = (nom, q, rayon, code) => [nom, q, 'ml', rayon, code, q];
const pc = (nom, n, rayon, code, grammes) => [nom, n, 'piece', rayon, code, grammes];

const huile = (q) => g('Huile d\'olive', q, EP, '17270');
const blancs = (q) => g('Blancs d\'œufs', q, CR, '22001');
const fb0 = (q) => g('Fromage blanc 0 %', q, CR, '19644');
const painComplet = (q) => g('Pain complet', q, BO, '7110');
const citron = (q) => g('Jus de citron', q, FL, '13009');

const RECETTES = [
  // Petits-déjeuners
  {
    id: 'seche_omelette_blancs_epinards', nom: 'Omelette de blancs aux épinards', moment: 'petitDejeuner', minutes: 10, vege: true,
    ing: [blancs(150), pc('Œuf', 1, CR, '22000', 60), g('Épinards frais', 80, FL, '20059'), painComplet(30), huile(3)],
    etapes: ['Fais tomber les épinards 1 minute dans une poêle huilée.', 'Bats les blancs avec l\'œuf entier, verse sur les épinards et cuis 3 minutes à feu moyen.', 'Sers avec le pain complet grillé.'],
  },
  {
    id: 'seche_fromage_blanc_avoine', nom: 'Fromage blanc 0 %, avoine et fruits rouges', moment: 'petitDejeuner', minutes: 3, vege: true,
    ing: [fb0(250), g('Flocons d\'avoine', 30, EP, '9311'), g('Fruits rouges', 100, FL, '13997')],
    etapes: ['Verse le fromage blanc dans un bol.', 'Ajoute les flocons d\'avoine et les fruits rouges.'],
  },
  {
    id: 'seche_pancakes_proteines', nom: 'Pancakes protéinés aux myrtilles', moment: 'petitDejeuner', minutes: 15, vege: true,
    ing: [blancs(120), g('Flocons d\'avoine', 40, EP, '9311'), fb0(100), g('Myrtilles', 60, FL, '13028')],
    etapes: ['Mixe les blancs, l\'avoine et le fromage blanc.', 'Cuis de petites louches 2 minutes de chaque côté dans une poêle antiadhésive.', 'Ajoute les myrtilles sur le dessus.'],
  },
  {
    id: 'seche_tartine_saumon', nom: 'Tartines saumon fumé et concombre', moment: 'petitDejeuner', minutes: 5,
    ing: [painComplet(50), g('Saumon fumé', 50, VP, '26037'), fb0(60), g('Concombre', 60, FL, '20019')],
    etapes: ['Tartine le pain de fromage blanc.', 'Ajoute le saumon fumé et des rondelles de concombre. Poivre.'],
  },
  {
    id: 'seche_oeufs_brouilles_jambon', nom: 'Œufs brouillés, jambon et tomate', moment: 'petitDejeuner', minutes: 8,
    ing: [pc('Œufs', 2, CR, '22000', 120), g('Jambon blanc dégraissé', 50, VP, '28906'), pc('Tomate', 1, FL, '20047', 100), painComplet(30)],
    etapes: ['Brouille les œufs à feu doux dans une poêle antiadhésive en remuant sans cesse.', 'Ajoute le jambon coupé en lanières en fin de cuisson.', 'Sers avec la tomate en tranches et le pain.'],
  },
  {
    id: 'seche_petits_suisses_kiwi', nom: 'Petits-suisses 0 %, kiwi et avoine', moment: 'petitDejeuner', minutes: 3, vege: true,
    ing: [pc('Petits-suisses 0 %', 3, CR, '19663', 180), pc('Kiwis', 2, FL, '13021', 150), g('Flocons d\'avoine', 20, EP, '9311')],
    etapes: ['Mélange les petits-suisses, ajoute les kiwis coupés et l\'avoine.'],
  },
  // Déjeuners
  {
    id: 'seche_poulet_courgettes_quinoa', nom: 'Poulet, courgettes et quinoa', moment: 'dejeuner', minutes: 20,
    ing: [g('Blanc de poulet', 150, VP, '36017'), g('Courgette', 200, FL, '20021'), g('Quinoa cuit', 100, EP, '9341'), huile(5)],
    etapes: ['Cuis le quinoa selon le paquet.', 'Fais dorer le poulet en morceaux 8 minutes dans l\'huile.', 'Ajoute les courgettes en dés 6 minutes, puis le quinoa. Sale, poivre.'],
  },
  {
    id: 'seche_dinde_haricots_riz', nom: 'Escalope de dinde, haricots verts et riz', moment: 'dejeuner', minutes: 20,
    ing: [g('Escalope de dinde', 150, VP, '36304'), g('Haricots verts', 200, FL, '20030'), g('Riz basmati cuit', 100, EP, '9125'), huile(5)],
    etapes: ['Cuis le riz et les haricots verts à l\'eau.', 'Poêle l\'escalope 4 minutes de chaque côté dans l\'huile.', 'Sers ensemble, avec un filet de citron si tu veux.'],
  },
  {
    id: 'seche_steak_poivrons', nom: 'Steak haché 5 %, poêlée de poivrons et pommes de terre', moment: 'dejeuner', minutes: 25,
    ing: [g('Steak haché 5 %', 150, VP, '6250'), g('Poivrons', 150, FL, '20041'), g('Oignon', 50, FL, '20034'), g('Pommes de terre', 150, FL, '4003'), huile(3)],
    etapes: ['Cuis les pommes de terre à l\'eau 20 minutes.', 'Fais revenir l\'oignon et les poivrons en lanières 8 minutes dans l\'huile.', 'Cuis le steak 3 minutes de chaque côté.'],
  },
  {
    id: 'seche_salade_thon_oeuf', nom: 'Grande salade thon, œuf et maïs', moment: 'dejeuner', minutes: 12,
    ing: [g('Thon au naturel', 120, EP, '26039'), pc('Œuf dur', 1, CR, '22010', 55), g('Laitue', 80, FL, '20031'), pc('Tomate', 1, FL, '20047', 150), g('Concombre', 100, FL, '20019'), g('Maïs', 40, EP, '20066'), ml('Vinaigre', 10, EP, '11018'), huile(5)],
    etapes: ['Cuis l\'œuf 9 minutes, refroidis-le et coupe-le en quartiers.', 'Mélange la salade, la tomate, le concombre, le maïs et le thon émietté.', 'Assaisonne d\'huile et de vinaigre.'],
  },
  {
    id: 'seche_bowl_poulet_lentilles', nom: 'Bowl poulet, lentilles et sauce citronnée', moment: 'dejeuner', minutes: 15,
    ing: [g('Blanc de poulet', 130, VP, '36017'), g('Lentilles cuites', 120, EP, '20505'), g('Tomates cerises', 100, FL, '20172'), g('Concombre', 80, FL, '20019'), fb0(50), citron(10)],
    etapes: ['Poêle le poulet en lanières 8 minutes sans matière grasse.', 'Dispose les lentilles, les tomates et le concombre dans un bol, puis le poulet.', 'Mélange le fromage blanc et le citron pour la sauce.'],
  },
  {
    id: 'seche_pates_thon_tomate', nom: 'Pâtes complètes au thon, tomate et courgette', moment: 'dejeuner', minutes: 15,
    ing: [g('Pâtes complètes cuites', 150, EP, '9871'), g('Thon au naturel', 100, EP, '26039'), g('Coulis de tomate', 120, EP, '20260'), g('Courgette', 150, FL, '20021'), g('Basilic', 5, FL, '11033')],
    etapes: ['Cuis les pâtes.', 'Fais revenir la courgette en dés 5 minutes, ajoute le coulis et le thon, laisse chauffer 3 minutes.', 'Mélange avec les pâtes et le basilic.'],
  },
  {
    id: 'seche_wrap_poulet', nom: 'Wrap poulet, crudités et fromage blanc', moment: 'dejeuner', minutes: 10,
    ing: [pc('Tortilla de blé', 1, BO, '7815', 40), g('Blanc de poulet cuit', 100, VP, '36018'), g('Laitue', 40, FL, '20031'), g('Tomate', 80, FL, '20047'), fb0(40)],
    etapes: ['Tartine la tortilla de fromage blanc poivré.', 'Ajoute la salade, la tomate et le poulet en lanières, puis roule serré.'],
  },
  {
    id: 'seche_galette_sarrasin', nom: 'Galette de sarrasin jambon, œuf et champignons', moment: 'dejeuner', minutes: 12,
    ing: [pc('Galette de sarrasin', 1, BO, '23801', 60), g('Jambon blanc dégraissé', 50, VP, '28906'), pc('Œuf', 1, CR, '22000', 60), g('Champignons', 80, FL, '20056'), g('Salade verte', 50, FL, '20031')],
    etapes: ['Poêle les champignons émincés 5 minutes.', 'Réchauffe la galette, casse l\'œuf au centre, ajoute jambon et champignons.', 'Replie les bords et cuis 3 minutes. Sers avec la salade.'],
  },
  {
    id: 'seche_salade_crevettes_avocat', nom: 'Salade de crevettes, avocat et maïs', moment: 'dejeuner', minutes: 10,
    ing: [g('Crevettes cuites décortiquées', 150, VP, '10007'), g('Avocat', 40, FL, '13004'), g('Laitue', 80, FL, '20031'), g('Tomates cerises', 100, FL, '20172'), g('Maïs', 30, EP, '20066'), citron(10)],
    etapes: ['Mélange la salade, les tomates coupées, le maïs et l\'avocat en dés.', 'Ajoute les crevettes et arrose de citron.'],
  },
  {
    id: 'seche_tofu_saute', nom: 'Tofu sauté aux légumes et sauce soja', moment: 'dejeuner', minutes: 15, vege: true,
    ing: [g('Tofu nature', 180, EP, '20904'), g('Brocoli', 150, FL, '20006'), g('Poivron', 100, FL, '20041'), ml('Sauce soja', 10, EP, '11104'), g('Riz basmati cuit', 50, EP, '9125')],
    etapes: ['Coupe le tofu en dés et fais-le dorer 5 minutes dans une poêle antiadhésive.', 'Ajoute le brocoli et le poivron, puis la sauce soja, 6 minutes.', 'Sers avec le riz.'],
  },
  // Dîners
  {
    id: 'seche_cabillaud_brocoli', nom: 'Cabillaud au citron, brocoli et patate douce', moment: 'diner', minutes: 25,
    ing: [g('Dos de cabillaud', 180, VP, '26043'), g('Brocoli', 200, FL, '20006'), g('Patate douce', 150, FL, '4102'), huile(5), citron(20)],
    etapes: ['Cuis la patate douce en dés et le brocoli à la vapeur 15 minutes.', 'Cuis le cabillaud au four 12 minutes à 200 °C avec le citron.', 'Arrose d\'un filet d\'huile.'],
  },
  {
    id: 'seche_crevettes_wok', nom: 'Wok de crevettes et légumes croquants', moment: 'diner', minutes: 15,
    ing: [g('Crevettes crues', 180, VP, '10021'), g('Brocoli', 150, FL, '20006'), g('Poivron', 100, FL, '20041'), g('Carotte', 80, FL, '20009'), ml('Sauce soja', 10, EP, '11104'), g('Riz basmati cuit', 80, EP, '9125'), huile(5)],
    etapes: ['Fais sauter les légumes en lamelles 5 minutes à feu vif dans l\'huile.', 'Ajoute les crevettes et la sauce soja, 3 minutes.', 'Sers avec le riz.'],
  },
  {
    id: 'seche_chili_maigre', nom: 'Chili au bœuf 5 % et haricots rouges', moment: 'diner', minutes: 25,
    ing: [g('Steak haché 5 %', 120, VP, '6250'), g('Haricots rouges', 120, EP, '20524'), g('Coulis de tomate', 150, EP, '20260'), g('Oignon', 50, FL, '20034'), g('Poivron', 100, FL, '20041'), g('Cumin', 2, EP, '11042')],
    etapes: ['Fais revenir l\'oignon et le poivron 5 minutes.', 'Ajoute la viande et fais-la dorer en l\'émiettant.', 'Ajoute le coulis, les haricots égouttés et le cumin, mijote 15 minutes.'],
  },
  {
    id: 'seche_papillote_lieu', nom: 'Papillote de lieu aux poireaux', moment: 'diner', minutes: 30,
    ing: [g('Filet de lieu noir', 180, VP, '26047'), g('Poireaux', 200, FL, '20040'), g('Pommes de terre', 150, FL, '4003'), citron(20), huile(3)],
    etapes: ['Émince les poireaux et fais-les fondre 8 minutes.', 'Dépose le poisson sur les poireaux dans du papier cuisson, arrose de citron et d\'huile, ferme.', 'Cuis 15 minutes à 200 °C. Sers avec les pommes de terre vapeur.'],
  },
  {
    id: 'seche_omelette_champignons', nom: 'Omelette aux champignons et salade', moment: 'diner', minutes: 12, vege: true,
    ing: [pc('Œufs', 2, CR, '22000', 120), blancs(100), g('Champignons', 150, FL, '20056'), g('Salade verte', 80, FL, '20031'), painComplet(30), huile(3)],
    etapes: ['Poêle les champignons émincés 5 minutes dans l\'huile.', 'Bats les œufs et les blancs, verse sur les champignons et cuis 4 minutes.', 'Sers avec la salade et le pain.'],
  },
  {
    id: 'seche_rumsteck_asperges', nom: 'Rumsteck grillé, asperges et pommes de terre', moment: 'diner', minutes: 20,
    ing: [g('Rumsteck', 150, VP, '6206'), g('Asperges vertes', 200, FL, '20001'), g('Pommes de terre', 120, FL, '4003'), huile(3)],
    etapes: ['Cuis les pommes de terre 20 minutes et les asperges 8 minutes à l\'eau.', 'Grille le rumsteck 2 à 3 minutes de chaque côté selon ton goût.', 'Arrose les légumes d\'un filet d\'huile.'],
  },
  {
    id: 'seche_veau_champignons', nom: 'Escalope de veau, champignons et riz complet', moment: 'diner', minutes: 20,
    ing: [g('Escalope de veau', 150, VP, '6521'), g('Champignons', 150, FL, '20056'), fb0(50), g('Riz complet cuit', 80, EP, '9103'), g('Persil', 5, FL, '11014')],
    etapes: ['Poêle l\'escalope 3 minutes de chaque côté et réserve.', 'Fais revenir les champignons 6 minutes, ajoute le fromage blanc hors du feu pour la sauce.', 'Sers avec le riz et le persil.'],
  },
  {
    id: 'seche_truite_fenouil', nom: 'Truite vapeur, fenouil fondant et quinoa', moment: 'diner', minutes: 25,
    ing: [g('Filet de truite', 150, VP, '27007'), g('Fenouil', 200, FL, '20118'), g('Quinoa cuit', 80, EP, '9341'), citron(10)],
    etapes: ['Cuis le fenouil émincé à l\'eau 12 minutes.', 'Cuis la truite à la vapeur 8 minutes.', 'Sers avec le quinoa et un filet de citron.'],
  },
  {
    id: 'seche_soupe_poulet', nom: 'Soupe de poulet aux légumes et pâtes', moment: 'diner', minutes: 30,
    ing: [g('Blanc de poulet', 120, VP, '36017'), g('Carotte', 100, FL, '20009'), g('Poireau', 100, FL, '20040'), g('Courgette', 100, FL, '20021'), g('Pâtes complètes cuites', 60, EP, '9871'), ml('Bouillon de légumes', 300, EP, '25948')],
    etapes: ['Fais cuire les légumes en dés dans le bouillon 15 minutes.', 'Ajoute le poulet en petits morceaux et cuis 8 minutes.', 'Ajoute les pâtes cuites et sers chaud.'],
  },
  {
    id: 'seche_curry_lentilles_corail', nom: 'Curry de lentilles corail aux épinards', moment: 'diner', minutes: 25, vege: true,
    ing: [g('Lentilles corail cuites', 180, EP, '20589'), fb0(100), g('Épinards frais', 100, FL, '20059'), pc('Tomate', 1, FL, '20047', 100), g('Oignon', 40, FL, '20034'), g('Curry', 2, EP, '11005')],
    etapes: ['Fais revenir l\'oignon avec le curry 3 minutes.', 'Ajoute la tomate, les lentilles cuites et les épinards, 8 minutes.', 'Hors du feu, ajoute le fromage blanc.'],
  },
  // Collations
  {
    id: 'seche_fromage_blanc_cacao', nom: 'Fromage blanc 0 % au cacao et framboises', moment: 'collation', minutes: 2, vege: true,
    ing: [fb0(200), g('Cacao non sucré', 5, EP, '18100'), g('Framboises', 60, FL, '13015')],
    etapes: ['Mélange le cacao au fromage blanc et ajoute les framboises.'],
  },
  {
    id: 'seche_oeufs_durs_radis', nom: 'Œuf dur, radis et fromage blanc aux herbes', moment: 'collation', minutes: 10, vege: true,
    ing: [pc('Œuf dur', 1, CR, '22010', 55), fb0(100), g('Radis', 100, FL, '20045'), g('Persil', 5, FL, '11014')],
    etapes: ['Cuis l\'œuf 9 minutes, refroidis-le et écale-le.', 'Mélange le fromage blanc avec le persil haché, du sel et du poivre.', 'Trempe les radis et l\'œuf dans la sauce.'],
  },
  {
    id: 'seche_roules_jambon', nom: 'Roulés de jambon au fromage blanc', moment: 'collation', minutes: 5,
    ing: [g('Jambon blanc dégraissé', 60, VP, '28906'), fb0(60), g('Concombre', 80, FL, '20019')],
    etapes: ['Tartine les tranches de jambon de fromage blanc poivré et roule-les.', 'Sers avec le concombre en bâtonnets.'],
  },
  {
    id: 'seche_petits_suisses_pomme', nom: 'Petits-suisses 0 % et pomme', moment: 'collation', minutes: 2, vege: true,
    ing: [pc('Petits-suisses 0 %', 2, CR, '19663', 120), pc('Pomme', 1, FL, '13039', 100)],
    etapes: ['Coupe la pomme en dés et mélange-la aux petits-suisses avec de la cannelle.'],
  },
  {
    id: 'seche_galettes_thon', nom: 'Galettes de riz au thon et concombre', moment: 'collation', minutes: 5,
    ing: [pc('Galettes de riz', 2, EP, '7352', 18), g('Thon au naturel', 80, EP, '26039'), fb0(30), g('Concombre', 60, FL, '20019')],
    etapes: ['Mélange le thon et le fromage blanc.', 'Étale sur les galettes et ajoute le concombre en rondelles.'],
  },
];

/** Apports d'une portion, calculés depuis Ciqual. */
export function apports(ingredients) {
  const t = { kcal: 0, proteines: 0, glucides: 0, lipides: 0 };
  for (const [nom, , , , code, grammes] of ingredients) {
    const a = parCode.get(code);
    if (!a) throw new Error(`${nom} : code Ciqual ${code} absent`);
    for (const k of Object.keys(t)) t[k] += ((a[col[k]] ?? 0) * grammes) / 100;
  }
  return t;
}

const RAYON = { fl: '_fl', bo: '_bo', vp: '_vp', cr: '_cr', ep: '_ep' };
const UNITE = { g: 'Unite.g', ml: 'Unite.ml', piece: 'Unite.piece' };
const dart = (s) => `'${s.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'`;
const arrondi = (x) => Math.round(x);

let sortie = `// Fichier généré par tool/recettes_seche.mjs : ne pas modifier à la main.
// Apports calculés depuis la table Ciqual 2020 de l'ANSES (CC BY 4.0).
import '../journal/modele.dart';
import 'modele.dart';

const _fl = Rayon.fruitsLegumes;
const _bo = Rayon.boulangerie;
const _vp = Rayon.viandePoisson;
const _cr = Rayon.cremerieOeufs;
const _ep = Rayon.epicerie;

/// Recettes pour une sèche : beaucoup de protéines, peu de calories.
const recettesSeche = <Recette>[
`;
const bilan = [];
for (const r of RECETTES) {
  const m = apports(r.ing);
  const part = (m.proteines * 4) / m.kcal;
  bilan.push(`${r.id.padEnd(34)} ${arrondi(m.kcal)} kcal  P ${arrondi(m.proteines)} g (${Math.round(part * 100)} %)  G ${arrondi(m.glucides)}  L ${arrondi(m.lipides)}`);
  sortie += `  Recette(
    id: '${r.id}',
    nom: ${dart(r.nom)},
    moment: Moment.${r.moment},
    minutes: ${r.minutes},${r.vege ? '\n    vegetarien: true,' : ''}
    macros: Macros(kcal: ${arrondi(m.kcal)}, proteines: ${arrondi(m.proteines)}, glucides: ${arrondi(m.glucides)}, lipides: ${arrondi(m.lipides)}),
    ingredients: [
${r.ing.map(([nom, q, u, ray]) => `      Ingredient(${dart(nom)}, ${q}, ${UNITE[u]}, ${RAYON[ray]}),`).join('\n')}
    ],
    etapes: [
${r.etapes.map((e) => `      ${dart(e)},`).join('\n')}
    ],
  ),
`;
}
sortie += '];\n';
writeFileSync(join(ici, 'lib', 'recettes', 'recettes_seche.dart'), sortie);
console.log(bilan.join('\n'));
