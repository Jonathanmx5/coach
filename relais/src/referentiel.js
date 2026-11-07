// Valeurs nutritionnelles usuelles (pour 100 g, aliment tel qu'on le mange :
// riz et pâtes cuits, viande cuite...). Les modèles d'IA se trompent souvent
// sur la densité calorique d'un aliment pourtant connu (du riz cuit à 50 kcal
// pour 100 g, par exemple) : quand le nom est sans ambiguïté et que leurs
// calories s'écartent de plus de 25 % de ces repères, on garde la quantité en
// grammes estimée par le modèle mais on recalcule les apports avec ce tableau.
//
// Liste blanche stricte : le nom doit être exactement un mot-clé, une fois
// retirés les adjectifs neutres (cuit, nature, vapeur, grillé, blanc). « Pain
// au chocolat », « Jambon cru » ou « Escalope de poulet panée » ne sont donc
// jamais corrigés : mieux vaut laisser la valeur du modèle que la remplacer
// par celle d'un autre aliment.
//
// Ordres de grandeur arrondis, d'après les tables usuelles (Ciqual, USDA) ; ce
// ne sont pas des valeurs de laboratoire. Colonnes : kcal, protéines, glucides
// (dont sucres), lipides (dont saturés).

// « œ » et « æ » n'ont pas de décomposition canonique : on les écrit à la main.
const sansAccents = (s) =>
  s
    .replace(/œ/gi, 'oe')
    .replace(/æ/gi, 'ae')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

// [mots, exclure (débuts de mot), kcal, p, g, sucres, l, saturés]
const LIGNES = [
  [['frites'], [], 300, 3.5, 40, 0.3, 14, 2],
  [['riz'], ['au lait', 'cru', 'sec', 'souffle', 'galette', 'gateau', 'frit', 'cantonais'], 130, 2.7, 28, 0.1, 0.3, 0.1],
  [['pates', 'spaghetti', 'spaghettis', 'tagliatelles', 'macaroni', 'macaronis', 'penne', 'fusilli', 'linguine', 'nouilles'], ['cru', 'seche', 'sec', 'salade', 'carbonara'], 158, 5.8, 31, 0.6, 0.9, 0.2],
  [['quinoa'], ['cru', 'sec', 'barre'], 120, 4.4, 21, 0.9, 1.9, 0.2],
  [['couscous', 'semoule', 'boulgour'], ['cru', 'sec', 'gateau'], 120, 4, 24, 0.5, 0.5, 0.1],
  [['patate douce', 'patates douces'], ['frit'], 90, 1.6, 21, 6, 0.1, 0],
  [['pomme de terre', 'pommes de terre', 'purée', 'puree'], ['chips', 'frit', 'gratin', 'saute', 'rissole', 'four', 'roti'], 86, 1.7, 20, 0.8, 0.1, 0],
  [['haricots rouges', 'haricot rouge'], [], 127, 8.7, 23, 0.3, 0.5, 0.1],
  [['lentilles', 'lentille'], ['cru', 'sec'], 116, 9, 20, 1.8, 0.4, 0.1],
  [['pois chiches', 'pois chiche'], ['houmous', 'hummus'], 164, 8.9, 27, 4.8, 2.6, 0.3],
  [['haricots verts', 'haricot vert'], [], 31, 1.8, 6, 1.4, 0.2, 0],
  [['blanc de poulet', 'blancs de poulet', 'filet de poulet', 'poulet'], ['pan', 'frit', 'nuggets', 'curry', 'sauce'], 165, 31, 0, 0, 3.6, 1],
  [['dinde', 'blanc de dinde', 'escalope de dinde'], ['pan', 'frit', 'sauce'], 150, 30, 0, 0, 2.5, 0.7],
  [['jambon', 'jambon blanc'], ['cru', 'bayonne', 'parme', 'serrano', 'fume'], 107, 18, 0.5, 0.3, 3.5, 1.2],
  [['steak', 'boeuf'], ['sauce', 'bolognaise', 'hache'], 220, 27, 0, 0, 12, 5],
  [['saumon'], ['fume'], 206, 22, 0, 0, 12.4, 2.5],
  [['cabillaud', 'poisson blanc', 'colin', 'merlu'], ['pan', 'frit'], 105, 23, 0, 0, 0.9, 0.2],
  [['thon'], ['huile'], 116, 26, 0, 0, 1, 0.3],
  [['crevettes', 'crevette'], ['pan', 'frit'], 99, 24, 0.2, 0, 0.3, 0.1],
  [['oeuf', 'oeufs', 'omelette'], [], 143, 12.6, 0.7, 0.4, 9.5, 3.1],
  [['pain', 'baguette'], ['perdu', 'epice', 'chocolat', 'raisin', 'lait', 'brioche'], 265, 9, 49, 3, 3.2, 0.7],
  [['fromage blanc'], [], 60, 8, 4, 4, 0.5, 0.3],
  [['yaourt'], ['grec', 'fruit', 'sucre'], 55, 4, 5.5, 5, 1.5, 1],
  [['mozzarella'], [], 280, 18, 2, 1, 21, 13],
  [['fromage'], ['raclette', 'fondue', 'frais', 'allege'], 350, 24, 1, 0.5, 28, 18],
  [['beurre'], ['cacahuete'], 717, 0.7, 0.1, 0.1, 81, 51],
  [['huile', "huile d'olive"], [], 900, 0, 0, 0, 100, 14],
  [['avocat'], [], 160, 2, 9, 0.7, 15, 2.1],
  [['tomate', 'tomates'], ['sauce', 'concentre', 'coulis'], 18, 0.9, 3.9, 2.6, 0.2, 0],
  [['concombre'], [], 12, 0.6, 2.2, 1.7, 0.1, 0],
  [['carotte', 'carottes'], [], 35, 0.8, 8, 4.7, 0.2, 0],
  [['courgette', 'courgettes'], [], 17, 1.2, 3, 2.5, 0.3, 0.1],
  [['brocoli', 'brocolis'], [], 35, 2.4, 7, 1.7, 0.4, 0.1],
  [['chou-fleur'], [], 25, 2, 5, 2, 0.3, 0.1],
  [['poivron', 'poivrons'], [], 26, 1, 6, 4.2, 0.3, 0.1],
  [['oignon', 'oignons'], [], 40, 1.1, 9, 4.2, 0.1, 0],
  [['champignon', 'champignons'], [], 22, 3, 3, 1.7, 0.3, 0],
  [['epinards', 'epinard'], [], 23, 3, 3.6, 0.4, 0.3, 0.1],
  [['salade', 'salade verte', 'laitue', 'roquette', 'mache'], [], 15, 1.4, 2.9, 0.8, 0.2, 0],
  [['pomme', 'pommes'], [], 52, 0.3, 14, 10, 0.2, 0],
  [['banane', 'bananes'], [], 89, 1.1, 23, 12, 0.3, 0.1],
  [['orange', 'clementine', 'mandarine'], ['jus'], 47, 0.9, 12, 9, 0.1, 0],
  [['fraises', 'fraise'], [], 32, 0.7, 8, 4.9, 0.3, 0],
  // Valeur de l'avoine sèche (flocons tels quels, muesli) : un porridge ou
  // une bouillie, cuits avec de l'eau ou du lait, sont écartés.
  [["flocons d'avoine", 'avoine'], ['barre', 'porridge', 'bouillie', 'lait', 'cuit'], 370, 13, 60, 1, 7, 1.2],
  [['tofu'], [], 120, 13, 2, 0.5, 7, 1],
];

// Plats composés : le nom d'un ingrédient ne suffit pas à donner les apports.
// Précaution en plus de la liste blanche (aucun mot-clé n'en contient).
const COMPOSES = [
  'sauce',
  'soupe',
  'gratin',
  'gateau',
  'tarte',
  'pizza',
  'burger',
  'sandwich',
  'curry',
  'chili',
  'bolognaise',
  'lasagne',
  'risotto',
  'paella',
  'quiche',
  'salade composee',
  'cesar',
  'ragout',
  'puree de',
  'et',
  'carbonara',
  'cantonais',
  'nicoise',
  'chevre',
  'grecque',
  'au fromage',
  'aux fromages',
  'steak de',
  'frit',
  'frite',
];

// Adjectifs qui ne changent pas les apports d'un aliment simple.
const NEUTRES = /(^| )(a la vapeur|a l'eau|vapeur|nature|cuit|cuite|cuits|cuites|grille|grillee|grilles|grillees)(?= |$)/g;
const BLANC = /(^| )(blanc|blanche|blancs|blanches)(?= |$)/g;

const REFERENCES = LIGNES.map(([mots, exclure, kcal, p, g, s, l, sat]) => ({
  mots: mots.map(sansAccents),
  exclure: exclure.map(sansAccents),
  kcal,
  p,
  g,
  s,
  l,
  sat,
}));

const echapper = (mot) => mot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const contient = (texte, mot) => new RegExp(`(^|[^a-z])${echapper(mot)}([^a-z]|$)`).test(texte);
// Exclusion par début de mot : « pan » écarte « pané », « panée », « panées ».
const commencePar = (texte, debut) => new RegExp(`(^|[^a-z])${echapper(debut)}`).test(texte);

const espaces = (s) => s.replace(/\s+/g, ' ').trim();

/**
 * Repère nutritionnel d'un aliment d'après son nom, ou null s'il n'est pas
 * sûr (plat composé, aliment cru ou transformé, nom inconnu ou précisé).
 */
export function referentiel(nom) {
  if (typeof nom !== 'string') return null;
  // Retire les précisions entre parenthèses : « Poisson (halibut ou saumon) ».
  const n = espaces(
    sansAccents(nom.replace(/\([^)]*\)/g, ' '))
      .replace(/[’`]/g, "'")
      .replace(/[.,;:!]/g, ' '),
  );
  if (n === '') return null;
  if (COMPOSES.some((c) => contient(n, c))) return null;
  // Le nom tel quel, puis sans les adjectifs neutres : en gardant « blanc »
  // d'abord (« Blanc de poulet grillé »), puis sans lui (« Riz blanc »).
  const sansNeutres = espaces(n.replace(NEUTRES, ' '));
  const candidats = [n, sansNeutres, espaces(sansNeutres.replace(BLANC, ' '))];
  for (const c of candidats) {
    if (c === '') continue;
    const r = REFERENCES.find((ref) => ref.mots.includes(c));
    if (r) return r.exclure.some((e) => commencePar(n, e)) ? null : r;
  }
  return null;
}
