import '../journal/modele.dart';
import 'modele.dart';

const _fl = Rayon.fruitsLegumes;
const _bo = Rayon.boulangerie;
const _vp = Rayon.viandePoisson;
const _cr = Rayon.cremerieOeufs;
const _ep = Rayon.epicerie;

/// Recettes simples pour débutants. Les apports sont approximatifs, pour une
/// portion (valeurs usuelles des tables nutritionnelles).
const catalogueRecettes = <Recette>[
  // Petits-déjeuners
  Recette(
    id: 'porridge_banane',
    nom: 'Porridge à la banane',
    moment: Moment.petitDejeuner,
    minutes: 8,
    vegetarien: true,
    macros: Macros(kcal: 380, proteines: 14, glucides: 65, lipides: 7),
    ingredients: [
      Ingredient('Flocons d\'avoine', 60, Unite.g, _ep),
      Ingredient('Lait', 200, Unite.ml, _cr),
      Ingredient('Banane', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Chauffe le lait avec les flocons d\'avoine 5 minutes en remuant.',
      'Coupe la banane en rondelles et ajoute-la sur le dessus.',
    ],
  ),
  Recette(
    id: 'yaourt_muesli',
    nom: 'Yaourt grec, fruits rouges et muesli',
    moment: Moment.petitDejeuner,
    minutes: 3,
    vegetarien: true,
    macros: Macros(kcal: 320, proteines: 17, glucides: 38, lipides: 10),
    ingredients: [
      Ingredient('Yaourt grec', 150, Unite.g, _cr),
      Ingredient('Fruits rouges', 80, Unite.g, _fl),
      Ingredient('Muesli', 40, Unite.g, _ep),
    ],
    etapes: ['Verse le yaourt dans un bol, ajoute les fruits et le muesli.'],
  ),
  Recette(
    id: 'omelette_pain',
    nom: 'Omelette et pain complet',
    moment: Moment.petitDejeuner,
    minutes: 10,
    vegetarien: true,
    macros: Macros(kcal: 360, proteines: 22, glucides: 28, lipides: 17),
    ingredients: [
      Ingredient('Œufs', 2, Unite.piece, _cr),
      Ingredient('Pain complet', 60, Unite.g, _bo),
      Ingredient('Tomate', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Bats les œufs, cuis-les à la poêle 3 minutes en remuant.',
      'Sers avec le pain grillé et la tomate coupée.',
    ],
  ),
  Recette(
    id: 'tartine_avocat',
    nom: 'Tartines avocat et œuf',
    moment: Moment.petitDejeuner,
    minutes: 10,
    vegetarien: true,
    macros: Macros(kcal: 400, proteines: 14, glucides: 32, lipides: 24),
    ingredients: [
      Ingredient('Pain complet', 60, Unite.g, _bo),
      Ingredient('Avocat', 0.5, Unite.piece, _fl),
      Ingredient('Œufs', 1, Unite.piece, _cr),
    ],
    etapes: [
      'Fais cuire l\'œuf 6 minutes à l\'eau bouillante, écale-le.',
      'Écrase l\'avocat sur le pain grillé, ajoute l\'œuf coupé.',
    ],
  ),
  Recette(
    id: 'fromage_blanc_noix',
    nom: 'Fromage blanc, miel et noix',
    moment: Moment.petitDejeuner,
    minutes: 2,
    vegetarien: true,
    macros: Macros(kcal: 330, proteines: 20, glucides: 28, lipides: 15),
    ingredients: [
      Ingredient('Fromage blanc', 200, Unite.g, _cr),
      Ingredient('Miel', 15, Unite.g, _ep),
      Ingredient('Noix', 20, Unite.g, _ep),
    ],
    etapes: ['Mélange le fromage blanc et le miel, parsème de noix.'],
  ),
  // Déjeuners
  Recette(
    id: 'poulet_riz_brocoli',
    nom: 'Poulet, riz et brocoli',
    moment: Moment.dejeuner,
    minutes: 25,
    macros: Macros(kcal: 560, proteines: 45, glucides: 58, lipides: 14),
    ingredients: [
      Ingredient('Blanc de poulet', 150, Unite.g, _vp),
      Ingredient('Riz', 70, Unite.g, _ep),
      Ingredient('Brocoli', 150, Unite.g, _fl),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Cuis le riz selon le paquet.',
      'Fais dorer le poulet coupé en dés à la poêle avec l\'huile, 8 minutes.',
      'Cuis le brocoli à la vapeur 7 minutes et assemble le tout.',
    ],
  ),
  Recette(
    id: 'salade_thon_pates',
    nom: 'Salade de pâtes au thon',
    moment: Moment.dejeuner,
    minutes: 15,
    macros: Macros(kcal: 540, proteines: 35, glucides: 62, lipides: 15),
    ingredients: [
      Ingredient('Pâtes', 70, Unite.g, _ep),
      Ingredient('Thon en boîte', 100, Unite.g, _ep),
      Ingredient('Tomate', 1, Unite.piece, _fl),
      Ingredient('Concombre', 0.5, Unite.piece, _fl),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Cuis les pâtes, rafraîchis-les sous l\'eau froide.',
      'Mélange avec le thon égoutté, la tomate et le concombre en dés, et l\'huile.',
    ],
  ),
  Recette(
    id: 'chili_sin_carne',
    nom: 'Chili sin carne',
    moment: Moment.dejeuner,
    minutes: 30,
    vegetarien: true,
    macros: Macros(kcal: 520, proteines: 22, glucides: 88, lipides: 8),
    ingredients: [
      Ingredient('Haricots rouges (cuits)', 150, Unite.g, _ep),
      Ingredient('Tomates concassées', 200, Unite.g, _ep),
      Ingredient('Riz', 60, Unite.g, _ep),
      Ingredient('Oignon', 1, Unite.piece, _fl),
      Ingredient('Poivron', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Fais revenir l\'oignon et le poivron en morceaux 5 minutes.',
      'Ajoute les tomates et les haricots, laisse mijoter 15 minutes.',
      'Sers sur le riz cuit.',
    ],
  ),
  Recette(
    id: 'bowl_quinoa_pois_chiches',
    nom: 'Bowl quinoa, légumes et pois chiches',
    moment: Moment.dejeuner,
    minutes: 25,
    vegetarien: true,
    macros: Macros(kcal: 540, proteines: 22, glucides: 78, lipides: 14),
    ingredients: [
      Ingredient('Quinoa', 70, Unite.g, _ep),
      Ingredient('Pois chiches (cuits)', 120, Unite.g, _ep),
      Ingredient('Courgette', 1, Unite.piece, _fl),
      Ingredient('Carotte', 1, Unite.piece, _fl),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Cuis le quinoa 12 minutes à l\'eau.',
      'Poêle la courgette et la carotte en dés avec l\'huile 8 minutes.',
      'Compose le bol avec les pois chiches.',
    ],
  ),
  Recette(
    id: 'dinde_patate_douce',
    nom: 'Dinde, patate douce et haricots verts',
    moment: Moment.dejeuner,
    minutes: 30,
    macros: Macros(kcal: 480, proteines: 42, glucides: 55, lipides: 9),
    ingredients: [
      Ingredient('Escalope de dinde', 150, Unite.g, _vp),
      Ingredient('Patate douce', 250, Unite.g, _fl),
      Ingredient('Haricots verts', 150, Unite.g, _fl),
    ],
    etapes: [
      'Coupe la patate douce en cubes et cuis-la 20 minutes au four à 200 °C.',
      'Poêle la dinde 5 minutes de chaque côté.',
      'Cuis les haricots verts 8 minutes à l\'eau bouillante.',
    ],
  ),
  Recette(
    id: 'wrap_poulet',
    nom: 'Wrap au poulet et crudités',
    moment: Moment.dejeuner,
    minutes: 15,
    macros: Macros(kcal: 470, proteines: 34, glucides: 46, lipides: 16),
    ingredients: [
      Ingredient('Tortilla', 1, Unite.piece, _bo),
      Ingredient('Blanc de poulet', 100, Unite.g, _vp),
      Ingredient('Salade', 50, Unite.g, _fl),
      Ingredient('Tomate', 1, Unite.piece, _fl),
      Ingredient('Fromage blanc', 50, Unite.g, _cr),
    ],
    etapes: [
      'Poêle le poulet en lanières 6 minutes.',
      'Étale le fromage blanc sur la tortilla, garnis de salade, tomate et poulet, roule.',
    ],
  ),
  // Dîners
  Recette(
    id: 'saumon_riz_epinards',
    nom: 'Saumon, riz et épinards',
    moment: Moment.diner,
    minutes: 25,
    macros: Macros(kcal: 580, proteines: 36, glucides: 50, lipides: 26),
    ingredients: [
      Ingredient('Pavé de saumon', 140, Unite.g, _vp),
      Ingredient('Riz', 60, Unite.g, _ep),
      Ingredient('Épinards', 150, Unite.g, _fl),
    ],
    etapes: [
      'Cuis le riz.',
      'Cuis le saumon 4 minutes de chaque côté à la poêle.',
      'Fais tomber les épinards 3 minutes à la poêle.',
    ],
  ),
  Recette(
    id: 'soupe_lentilles',
    nom: 'Soupe de lentilles corail',
    moment: Moment.diner,
    minutes: 25,
    vegetarien: true,
    macros: Macros(kcal: 430, proteines: 24, glucides: 70, lipides: 5),
    ingredients: [
      Ingredient('Lentilles corail', 80, Unite.g, _ep),
      Ingredient('Carotte', 2, Unite.piece, _fl),
      Ingredient('Oignon', 1, Unite.piece, _fl),
      Ingredient('Pain complet', 40, Unite.g, _bo),
    ],
    etapes: [
      'Coupe l\'oignon et les carottes, mets-les avec les lentilles dans 500 ml d\'eau.',
      'Laisse cuire 20 minutes, mixe si tu aimes lisse. Sers avec le pain.',
    ],
  ),
  Recette(
    id: 'omelette_champignons',
    nom: 'Omelette aux champignons et salade',
    moment: Moment.diner,
    minutes: 15,
    vegetarien: true,
    macros: Macros(kcal: 400, proteines: 27, glucides: 8, lipides: 28),
    ingredients: [
      Ingredient('Œufs', 3, Unite.piece, _cr),
      Ingredient('Champignons', 150, Unite.g, _fl),
      Ingredient('Salade', 60, Unite.g, _fl),
      Ingredient('Huile d\'olive', 5, Unite.ml, _ep),
    ],
    etapes: [
      'Fais sauter les champignons émincés 5 minutes avec l\'huile.',
      'Verse les œufs battus, cuis 3 minutes et replie. Sers avec la salade.',
    ],
  ),
  Recette(
    id: 'steak_pommes_de_terre',
    nom: 'Steak haché, pommes de terre et haricots verts',
    moment: Moment.diner,
    minutes: 30,
    macros: Macros(kcal: 520, proteines: 34, glucides: 55, lipides: 16),
    ingredients: [
      Ingredient('Steak haché 5 % MG', 125, Unite.g, _vp),
      Ingredient('Pommes de terre', 250, Unite.g, _fl),
      Ingredient('Haricots verts', 150, Unite.g, _fl),
    ],
    etapes: [
      'Cuis les pommes de terre 20 minutes à l\'eau.',
      'Poêle le steak 3 minutes de chaque côté.',
      'Cuis les haricots verts 8 minutes.',
    ],
  ),
  Recette(
    id: 'curry_pois_chiches',
    nom: 'Curry de pois chiches et épinards',
    moment: Moment.diner,
    minutes: 25,
    vegetarien: true,
    macros: Macros(kcal: 600, proteines: 20, glucides: 80, lipides: 22),
    ingredients: [
      Ingredient('Pois chiches (cuits)', 150, Unite.g, _ep),
      Ingredient('Lait de coco', 100, Unite.ml, _ep),
      Ingredient('Riz', 60, Unite.g, _ep),
      Ingredient('Épinards', 100, Unite.g, _fl),
      Ingredient('Tomates concassées', 150, Unite.g, _ep),
    ],
    etapes: [
      'Cuis le riz.',
      'Chauffe les tomates, le lait de coco, 1 cuillère de curry et les pois chiches 10 minutes.',
      'Ajoute les épinards 2 minutes, sers sur le riz.',
    ],
  ),
  Recette(
    id: 'cabillaud_quinoa',
    nom: 'Cabillaud, légumes rôtis et quinoa',
    moment: Moment.diner,
    minutes: 30,
    macros: Macros(kcal: 450, proteines: 40, glucides: 45, lipides: 11),
    ingredients: [
      Ingredient('Dos de cabillaud', 160, Unite.g, _vp),
      Ingredient('Quinoa', 60, Unite.g, _ep),
      Ingredient('Courgette', 1, Unite.piece, _fl),
      Ingredient('Poivron', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Coupe courgette et poivron, rôtis-les 20 minutes au four à 200 °C.',
      'Ajoute le cabillaud sur la plaque les 10 dernières minutes.',
      'Cuis le quinoa 12 minutes et sers ensemble.',
    ],
  ),
  // Collations
  Recette(
    id: 'pomme_amandes',
    nom: 'Pomme et amandes',
    moment: Moment.collation,
    minutes: 2,
    vegetarien: true,
    macros: Macros(kcal: 230, proteines: 6, glucides: 28, lipides: 12),
    ingredients: [
      Ingredient('Pomme', 1, Unite.piece, _fl),
      Ingredient('Amandes', 25, Unite.g, _ep),
    ],
    etapes: ['Croque la pomme avec une poignée d\'amandes.'],
  ),
  Recette(
    id: 'skyr_banane',
    nom: 'Skyr et banane',
    moment: Moment.collation,
    minutes: 2,
    vegetarien: true,
    macros: Macros(kcal: 190, proteines: 17, glucides: 28, lipides: 1),
    ingredients: [
      Ingredient('Skyr', 150, Unite.g, _cr),
      Ingredient('Banane', 1, Unite.piece, _fl),
    ],
    etapes: ['Coupe la banane sur le skyr.'],
  ),
  Recette(
    id: 'houmous_legumes',
    nom: 'Houmous et bâtonnets de légumes',
    moment: Moment.collation,
    minutes: 5,
    vegetarien: true,
    macros: Macros(kcal: 190, proteines: 7, glucides: 18, lipides: 10),
    ingredients: [
      Ingredient('Houmous', 60, Unite.g, _cr),
      Ingredient('Carotte', 2, Unite.piece, _fl),
      Ingredient('Concombre', 0.5, Unite.piece, _fl),
    ],
    etapes: ['Taille les légumes en bâtonnets et trempe-les dans le houmous.'],
  ),
];

Recette recetteParId(String id) =>
    catalogueRecettes.firstWhere((r) => r.id == id);

Recette? recetteOuNull(String id) {
  for (final r in catalogueRecettes) {
    if (r.id == id) return r;
  }
  return null;
}
