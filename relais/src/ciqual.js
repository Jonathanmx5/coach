// Rapprochement d'un nom d'aliment donné par l'IA avec la table Ciqual de
// l'ANSES (2020, licence CC BY 4.0 : voir donnees/ciqual.json). L'IA reconnaît
// les aliments et estime les grammes ; les apports pour 100 g viennent de la
// table quand le rapprochement est sûr.
//
// Règles, volontairement prudentes (mieux vaut garder la valeur de l'IA que
// prendre celle d'un autre aliment) :
// - tous les mots du nom doivent se retrouver dans le libellé Ciqual ;
// - le premier mot du nom doit être le premier mot du libellé (« Poulet » ne
//   tombe pas sur « Pizza au poulet ») ;
// - chaque mot du libellé absent du nom coûte : peu pour une cuisson ou une
//   variété par défaut (« Riz » → « Riz blanc, cuit »), beaucoup pour ce qui
//   change les apports (cru, sec, en poudre, allégé...) ou pour une autre
//   variété (« Yaourt » ne devient pas « Yaourt à la grecque ») ; on garde le
//   libellé le moins coûteux s'il reste sous un seuil ;
// - si plusieurs libellés presque aussi bons donnent des calories trop
//   différentes (« Poulet » : filet ou cuisse ?), on ne choisit pas.
import table from '../donnees/ciqual.json' with { type: 'json' };

// « œ » et « æ » n'ont pas de décomposition canonique : on les écrit à la main.
const sansAccents = (s) =>
  s
    .replace(/œ/gi, 'oe')
    .replace(/æ/gi, 'ae')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

// Mots sans contenu : articles, prépositions, liaisons.
const VIDES = new Set(['de', 'du', 'des', 'la', 'le', 'les', 'l', 'd', 'a', 'au', 'aux', 'en', 'et', 'ou', 'un', 'une', 'avec', 'pour', 'sur', 'type', 'ex']);

// Racine grossière d'un mot : sans pluriel ni « e » final, pour que « cuites »,
// « cuite » et « cuit » (ou « pâtes » et « pâte ») se rejoignent. Appliquée
// pareil au nom et au libellé.
function racine(mot) {
  let m = mot;
  if (m.length > 3 && /[sx]$/.test(m)) m = m.slice(0, -1);
  while (m.length > 3 && m.endsWith('e')) m = m.slice(0, -1);
  return m;
}

// Mots d'un texte, racines sans accents. « Pâté » devient « terrine » pour ne
// pas se confondre avec « pâtes » une fois les accents retirés ; « non salé »
// devient un seul mot, qui ne change pas les apports.
function mots(texte) {
  const brut = sansAccents(
    texte.replace(/(^|[^a-zà-ÿ])pâtés?(?=[^a-zà-ÿ]|$)/gi, '$1terrine'),
  )
    .replace(/[’`]/g, "'")
    .split(/[^a-z0-9%]+/)
    .filter((m) => m !== '' && !VIDES.has(m));
  const sortie = [];
  for (let i = 0; i < brut.length; i++) {
    if (brut[i] === 'non' && i + 1 < brut.length) sortie.push(`non${racine(brut[++i])}`);
    else sortie.push(racine(brut[i]));
  }
  return sortie;
}

const ensemble = (liste) => new Set(liste.flatMap(mots));
// Hors du nom principal, ne changent pas (ou presque) les apports.
const GRATUITS = ensemble(['cuit', 'eau', 'aliment', 'moyen', 'précision', 'nature', 'courant', 'ordinaire', 'standard', 'maison', 'fait', 'pulpe', 'égoutté', 'entier', 'bouilli', 'four', 'artisanal', 'variétés', 'mélange', 'tradition', 'française', 'prêt', 'boire', 'consommer']);
// Manière de cuire : la même valeur à peu de chose près.
const CUISSONS = ensemble(['rôti', 'grillé', 'poêlé', 'sauté', 'braisé', 'micro-ondes', 'réchauffé', 'vapeur', 'infusé']);
// Choix par défaut d'une variété (« Riz blanc », « Lait demi-écrémé »).
const DEFAUTS = ensemble(['blanc', 'blanche', 'demi-écrémé', 'UHT', 'pasteurisé', 'élevage', 'nature', 'ordinaire', 'courant', 'standard']);
// Changent beaucoup les apports : à éviter s'ils ne sont pas dans le nom.
const LOURDS = ensemble(['cru', 'sec', 'séché', 'poudre', 'déshydraté', 'lyophilisé', 'concentré', 'flocons', 'allégé', '0%', 'édulcorants', 'alcool', 'sucré', 'gluten', 'light', 'frit', 'pané', 'farci', 'sauce', 'cuisson', 'surgelé', 'reconstitué', 'jus', 'sirop', 'confit', 'moulu', 'soluble', 'instantané', 'feuille', 'grains', 'frais', 'fraîche']);
// « Pâtes sèches, cuites » : pâtes du commerce, pas des pâtes sèches.
const SECS = ensemble(['sec', 'séché']);
// Groupes où l'aliment se mange d'ordinaire cru : « cru » n'y coûte rien,
// une cuisson si (« Pomme » n'est pas « Pomme cuite au four »).
const CRUS_NORMAUX = new Set(['fruits', 'légumes', 'fruits à coque et graines oléagineuses', 'salades composées et crudités', 'herbes']);
const CRU = racine('cru');

const COUT_TETE = 2;
const SEUIL = 1.6;
const ECART_TOLERE = 0.5;
const ECART_KCAL = 0.2;
const ECART_KCAL_ABSOLU = 15;

const ALIMENTS = table.aliments.map((ligne) => {
  const a = Object.fromEntries(table.colonnes.map((c, i) => [c, ligne[i]]));
  // Nom principal : avant la première virgule, sans parenthèses ; ce qui suit
  // un « ou » n'est qu'un autre nom du même aliment.
  const [principal, ...autres] = a.nom.split(',')[0].replace(/\([^)]*\)/g, ' ').split(/ ou /i);
  const tete = mots(principal);
  return {
    ...a,
    mots: new Set(mots(a.nom)),
    tete: new Set(tete),
    synonymes: new Set(autres.flatMap(mots)),
    premier: tete[0],
    generique: /aliment moyen|sans précision/i.test(a.nom),
    cruNormal: CRUS_NORMAUX.has(a.groupe),
  };
});
const PAR_PREMIER = new Map();
for (const a of ALIMENTS) {
  if (!a.premier || !Number.isFinite(a.kcal)) continue;
  if (!PAR_PREMIER.has(a.premier)) PAR_PREMIER.set(a.premier, []);
  PAR_PREMIER.get(a.premier).push(a);
}

// Aliments courants que la prudence ci-dessus écarterait (« Frites », « Huile
// d'olive », « Baguette »...) : correspondance choisie à la main, pour le nom
// entier seulement (« Poulet » seul reste sans réponse). Libellés Ciqual exacts.
const ALIAS = [
  [['poulet rôti', 'poulet roti'], 'Poulet, viande et peau, rôti/cuit au four'],
  [['poulet grillé', 'poulet grille'], 'Poulet, poitrine, viande et peau, rôti/cuit au four'],
  [['blanc de poulet', 'filet de poulet', 'escalope de poulet'], 'Poulet, filet, sans peau, sauté/poêlé'],
  [['jambon blanc', 'jambon cuit'], 'Jambon cuit, supérieur'],
  [['frites', 'frite', 'portion de frites'], 'Frites de pommes de terre, surgelées, cuites en friteuse'],
  [["huile d'olive", 'huile olive'], "Huile d'olive vierge extra"],
  [['baguette', 'pain blanc', 'baguette de pain'], 'Pain, baguette, courante'],
  [['spaghetti', 'spaghettis', 'tagliatelles', 'penne', 'fusilli', 'macaroni', 'coquillettes'], 'Pâtes sèches standard, cuites, non salées'],
  [['purée', 'purée de pommes de terre', 'purée de pomme de terre'], 'Pomme de terre, purée (aliment moyen)'],
  [['steak haché', 'steak hache'], 'Boeuf, steak haché 15% MG, cuit'],
  [['saumon'], 'Saumon, cuit, sans précision (aliment moyen)'],
  [['omelette'], 'Omelette, garnitures diverses : légumes, fromages, viandes... (aliment moyen)'],
  [['yaourt grec', 'yaourt à la grecque'], 'Yaourt à la grecque, nature'],
  [['mozzarella'], 'Mozzarella au lait de vache'],
  [['haricots verts', 'haricot vert'], 'Haricot vert, cuit'],
  [['courgette', 'courgettes'], 'Courgette, pulpe et peau, cuite'],
  [['épinards', 'épinard'], 'Épinard, cuit'],
  [['kiwi', 'kiwis'], 'Kiwi, pulpe et graines, cru'],
  [['noix'], 'Noix, séchée, cerneaux'],
  [['lentilles', 'lentille'], "Lentille, bouillie/cuite à l'eau"],
  [['pois chiches', 'pois chiche'], "Pois chiche, bouilli/cuit à l'eau"],
  [['boulgour'], 'Boulgour de blé, cuit, non salé'],
  [['semoule'], 'Semoule de blé dur, cuite, non salée'],
  [['petits pois'], 'Petits pois, cuits'],
  [['maïs', 'mais'], 'Maïs doux, appertisé, égoutté'],
];
const PAR_LIBELLE = new Map(ALIMENTS.map((a) => [a.nom, a]));
const PAR_ALIAS = new Map();
for (const [noms, libelle] of ALIAS) {
  const a = PAR_LIBELLE.get(libelle);
  if (!a) throw new Error(`Ciqual : libellé introuvable pour l'alias « ${noms[0]} » : ${libelle}`);
  for (const n of noms) PAR_ALIAS.set(mots(n).join(' '), a);
}

function cout(a, demande) {
  let c = a.generique ? -0.5 : 0;
  const cuit = a.mots.has('cuit');
  for (const m of a.mots) {
    if (demande.has(m)) continue;
    if (m.startsWith('non') && m.length > 3) c += 0.1;
    else if (a.cruNormal && m === CRU) c += 0;
    else if (cuit && SECS.has(m)) c += 0;
    else if (LOURDS.has(m)) c += 3;
    else if (a.cruNormal && (CUISSONS.has(m) || m === 'cuit' || m === 'bouilli' || m === 'four')) c += 0.6;
    else if (CUISSONS.has(m)) c += 0.2;
    else if (DEFAUTS.has(m)) c += 0.3;
    else if (a.tete.has(m)) c += COUT_TETE;
    else if (a.synonymes.has(m)) c += 0.2;
    else if (GRATUITS.has(m) || /^\d/.test(m)) c += 0;
    else c += 0.5;
  }
  return c;
}

/**
 * Aliment Ciqual correspondant au nom, ou null si le rapprochement n'est pas
 * sûr. Valeurs pour 100 g (kcal, p, g, s, l, sat) et libellé Ciqual.
 */
export function ciqual(nom) {
  if (typeof nom !== 'string') return null;
  // Retire les précisions entre parenthèses : « Poisson (halibut ou saumon) ».
  const liste = mots(nom.replace(/\([^)]*\)/g, ' '));
  if (liste.length === 0 || liste.length > 8) return null;
  const alias = PAR_ALIAS.get(liste.join(' '));
  if (alias) return valeurs(alias);
  const demande = new Set(liste);
  const candidats = [];
  for (const a of PAR_PREMIER.get(liste[0]) ?? []) {
    if (liste.every((m) => a.mots.has(m))) candidats.push({ a, c: cout(a, demande) });
  }
  if (candidats.length === 0) return null;
  candidats.sort((x, y) => x.c - y.c || x.a.mots.size - y.a.mots.size);
  const meilleur = candidats[0];
  if (meilleur.c > SEUIL) return null;
  const kcal = candidats.filter((x) => x.c - meilleur.c <= ECART_TOLERE).map((x) => x.a.kcal);
  const ecart = Math.max(...kcal) - Math.min(...kcal);
  if (ecart > ECART_KCAL_ABSOLU && ecart / Math.max(meilleur.a.kcal, 1) > ECART_KCAL) return null;
  return valeurs(meilleur.a);
}

function valeurs(a) {
  const g = a.glucides ?? 0;
  const l = a.lipides ?? 0;
  return {
    reference: a.nom,
    kcal: a.kcal,
    p: a.proteines ?? 0,
    g,
    s: Math.min(a.sucres ?? 0, g),
    l,
    sat: Math.min(a.satures ?? 0, l),
  };
}
