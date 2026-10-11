import '../journal/modele.dart';
import 'modele.dart';

const _fl = Rayon.fruitsLegumes;
const _bo = Rayon.boulangerie;
const _vp = Rayon.viandePoisson;
const _cr = Rayon.cremerieOeufs;
const _ep = Rayon.epicerie;

/// Recettes ajoutées pour varier les idées de repas.
const recettesSupplementaires = <Recette>[
  Recette(
    id: 'pancakes_avoine',
    nom: 'Pancakes à l\'avoine et à la banane',
    moment: Moment.petitDejeuner,
    minutes: 15,
    vegetarien: true,
    macros: Macros(kcal: 375, proteines: 16, glucides: 58, lipides: 9),
    ingredients: [
      Ingredient('Flocons d\'avoine', 50, Unite.g, _ep),
      Ingredient('Œufs', 1, Unite.piece, _cr),
      Ingredient('Banane', 1, Unite.piece, _fl),
      Ingredient('Lait', 50, Unite.ml, _cr),
    ],
    etapes: [
      'Mixe l\'avoine, l\'œuf, la banane et le lait jusqu\'à obtenir une pâte.',
      'Cuis de petites louches 2 minutes de chaque côté dans une poêle antiadhésive.',
    ],
  ),
  Recette(
    id: 'smoothie_bowl',
    nom: 'Smoothie bowl fruits rouges et granola',
    moment: Moment.petitDejeuner,
    minutes: 5,
    vegetarien: true,
    macros: Macros(kcal: 315, proteines: 13, glucides: 57, lipides: 6),
    ingredients: [
      Ingredient('Banane', 1, Unite.piece, _fl),
      Ingredient('Fruits rouges', 100, Unite.g, _fl),
      Ingredient('Fromage blanc', 100, Unite.g, _cr),
      Ingredient('Granola', 30, Unite.g, _ep),
    ],
    etapes: [
      'Mixe la banane, les fruits rouges et le fromage blanc.',
      'Verse dans un bol et ajoute le granola.',
    ],
  ),
  Recette(
    id: 'oeufs_brouilles_epinards',
    nom: 'Œufs brouillés aux épinards',
    moment: Moment.petitDejeuner,
    minutes: 10,
    vegetarien: true,
    macros: Macros(kcal: 340, proteines: 25, glucides: 20, lipides: 16),
    ingredients: [
      Ingredient('Œufs', 3, Unite.piece, _cr),
      Ingredient('Épinards', 100, Unite.g, _fl),
      Ingredient('Pain complet', 40, Unite.g, _bo),
    ],
    etapes: [
      'Fais tomber les épinards 2 minutes à la poêle.',
      'Ajoute les œufs battus et remue à feu doux 3 minutes.',
      'Sers avec le pain grillé.',
    ],
  ),
  Recette(
    id: 'poke_bowl_saumon',
    nom: 'Poke bowl au saumon et à l\'avocat',
    moment: Moment.dejeuner,
    minutes: 25,
    macros: Macros(kcal: 600, proteines: 27, glucides: 67, lipides: 25),
    ingredients: [
      Ingredient('Riz', 70, Unite.g, _ep),
      Ingredient('Pavé de saumon', 100, Unite.g, _vp),
      Ingredient('Avocat', 0.5, Unite.piece, _fl),
      Ingredient('Concombre', 0.5, Unite.piece, _fl),
      Ingredient('Carotte', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Cuis le riz et laisse-le tiédir.',
      'Cuis le saumon 8 minutes au four à 180 °C, émiette-le.',
      'Coupe l\'avocat, le concombre et la carotte, dispose le tout sur le riz.',
    ],
  ),
  Recette(
    id: 'bolognaise_dinde',
    nom: 'Pâtes complètes bolognaise à la dinde',
    moment: Moment.dejeuner,
    minutes: 30,
    macros: Macros(kcal: 510, proteines: 40, glucides: 71, lipides: 7),
    ingredients: [
      Ingredient('Pâtes complètes', 80, Unite.g, _ep),
      Ingredient('Dinde hachée', 125, Unite.g, _vp),
      Ingredient('Tomates concassées', 200, Unite.g, _ep),
      Ingredient('Oignon', 1, Unite.piece, _fl),
    ],
    etapes: [
      'Fais revenir l\'oignon haché puis la dinde 5 minutes.',
      'Ajoute les tomates et laisse mijoter 15 minutes.',
      'Cuis les pâtes et sers avec la sauce.',
    ],
  ),
  Recette(
    id: 'salade_lentilles_feta',
    nom: 'Salade de lentilles, feta et crudités',
    moment: Moment.dejeuner,
    minutes: 10,
    vegetarien: true,
    macros: Macros(kcal: 390, proteines: 20, glucides: 35, lipides: 19),
    ingredients: [
      Ingredient('Lentilles (cuites)', 150, Unite.g, _ep),
      Ingredient('Feta', 40, Unite.g, _cr),
      Ingredient('Tomate', 1, Unite.piece, _fl),
      Ingredient('Concombre', 0.5, Unite.piece, _fl),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Mélange les lentilles avec la tomate et le concombre en dés.',
      'Émiette la feta dessus et assaisonne avec l\'huile.',
    ],
  ),
  Recette(
    id: 'salade_poulet_croquante',
    nom: 'Salade de poulet croquante',
    moment: Moment.dejeuner,
    minutes: 15,
    macros: Macros(kcal: 345, proteines: 36, glucides: 20, lipides: 13),
    ingredients: [
      Ingredient('Blanc de poulet', 130, Unite.g, _vp),
      Ingredient('Salade', 80, Unite.g, _fl),
      Ingredient('Carotte', 1, Unite.piece, _fl),
      Ingredient('Maïs en boîte', 60, Unite.g, _ep),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Poêle le poulet 6 minutes, coupe-le en lanières.',
      'Râpe la carotte, mélange avec la salade et le maïs.',
      'Ajoute le poulet et l\'huile.',
    ],
  ),
  Recette(
    id: 'crevettes_riz_legumes',
    nom: 'Crevettes sautées, riz et légumes',
    moment: Moment.diner,
    minutes: 20,
    macros: Macros(kcal: 500, proteines: 40, glucides: 66, lipides: 7),
    ingredients: [
      Ingredient('Crevettes décortiquées', 150, Unite.g, _vp),
      Ingredient('Riz', 70, Unite.g, _ep),
      Ingredient('Poivron', 1, Unite.piece, _fl),
      Ingredient('Courgette', 1, Unite.piece, _fl),
      Ingredient('Huile d\'olive', 5, Unite.ml, _ep),
    ],
    etapes: [
      'Cuis le riz.',
      'Fais sauter poivron et courgette en dés 6 minutes avec l\'huile.',
      'Ajoute les crevettes 3 minutes et sers sur le riz.',
    ],
  ),
  Recette(
    id: 'tortilla_pommes_de_terre',
    nom: 'Tortilla aux pommes de terre',
    moment: Moment.diner,
    minutes: 35,
    vegetarien: true,
    macros: Macros(kcal: 530, proteines: 23, glucides: 51, lipides: 25),
    ingredients: [
      Ingredient('Œufs', 3, Unite.piece, _cr),
      Ingredient('Pommes de terre', 250, Unite.g, _fl),
      Ingredient('Oignon', 1, Unite.piece, _fl),
      Ingredient('Huile d\'olive', 10, Unite.ml, _ep),
    ],
    etapes: [
      'Émince les pommes de terre et l\'oignon, cuis-les 15 minutes à la poêle avec l\'huile.',
      'Verse les œufs battus et cuis 5 minutes à feu doux.',
      'Retourne la tortilla avec une assiette et cuis encore 3 minutes.',
    ],
  ),
  Recette(
    id: 'pita_pizza_legumes',
    nom: 'Pizza pita mozzarella et légumes',
    moment: Moment.diner,
    minutes: 20,
    vegetarien: true,
    macros: Macros(kcal: 390, proteines: 20, glucides: 46, lipides: 13),
    ingredients: [
      Ingredient('Pain pita complet', 1, Unite.piece, _bo),
      Ingredient('Mozzarella', 60, Unite.g, _cr),
      Ingredient('Tomates concassées', 100, Unite.g, _ep),
      Ingredient('Poivron', 1, Unite.piece, _fl),
      Ingredient('Champignons', 80, Unite.g, _fl),
    ],
    etapes: [
      'Étale les tomates sur le pita, ajoute les légumes émincés et la mozzarella.',
      'Enfourne 10 minutes à 200 °C.',
    ],
  ),
  Recette(
    id: 'poulet_curry_coco',
    nom: 'Poulet au curry et lait de coco',
    moment: Moment.diner,
    minutes: 30,
    macros: Macros(kcal: 600, proteines: 42, glucides: 55, lipides: 22),
    ingredients: [
      Ingredient('Blanc de poulet', 150, Unite.g, _vp),
      Ingredient('Lait de coco', 100, Unite.ml, _ep),
      Ingredient('Riz', 60, Unite.g, _ep),
      Ingredient('Tomates concassées', 100, Unite.g, _ep),
    ],
    etapes: [
      'Cuis le riz.',
      'Fais dorer le poulet en dés, ajoute 1 cuillère de curry, les tomates et le lait de coco.',
      'Laisse mijoter 12 minutes et sers sur le riz.',
    ],
  ),
  Recette(
    id: 'galettes_cacahuete',
    nom: 'Galettes de riz et beurre de cacahuète',
    moment: Moment.collation,
    minutes: 2,
    vegetarien: true,
    macros: Macros(kcal: 225, proteines: 7, glucides: 26, lipides: 10),
    ingredients: [
      Ingredient('Galettes de riz', 3, Unite.piece, _ep),
      Ingredient('Beurre de cacahuète', 20, Unite.g, _ep),
    ],
    etapes: ['Étale le beurre de cacahuète sur les galettes.'],
  ),
  Recette(
    id: 'smoothie_banane_proteine',
    nom: 'Smoothie banane, avoine et fromage blanc',
    moment: Moment.collation,
    minutes: 4,
    vegetarien: true,
    macros: Macros(kcal: 340, proteines: 20, glucides: 48, lipides: 6),
    ingredients: [
      Ingredient('Banane', 1, Unite.piece, _fl),
      Ingredient('Lait', 250, Unite.ml, _cr),
      Ingredient('Flocons d\'avoine', 20, Unite.g, _ep),
      Ingredient('Fromage blanc', 100, Unite.g, _cr),
    ],
    etapes: ['Mixe tous les ingrédients jusqu\'à obtenir une boisson lisse.'],
  ),
];
