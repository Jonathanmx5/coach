// Génère les photos des recettes avec Cloudflare Workers AI (flux-1-schnell,
// licence Apache 2.0). À lancer une fois ; les images sont ensuite dans
// assets/recettes/. Usage : node tool/generer_images.mjs [id ...]
// Nécessite d'être connecté à wrangler (npx wrangler login).
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const COMPTE = process.env.CF_ACCOUNT_ID ?? '7f23348331dcc3939f89ea82b9c0a1f1';
const JETON = readFileSync(
  `${process.env.APPDATA}/xdg.config/.wrangler/config/default.toml`,
  'utf8',
).match(/oauth_token\s*=\s*"([^"]+)"/)[1];

const STYLE =
  'professional food photography, appetizing, natural window light, rustic wooden table, shallow depth of field, no text, no people';

const PLATS = {
  porridge_banane: 'a bowl of oatmeal porridge topped with sliced banana',
  yaourt_muesli: 'greek yogurt in a bowl with fresh red berries and muesli',
  omelette_pain: 'a golden omelette with whole wheat toast and sliced tomato',
  fromage_blanc_noix: 'white cheese in a bowl drizzled with honey and walnuts',
  poulet_riz_brocoli: 'grilled chicken pieces with white rice and steamed broccoli on a plate',
  salade_thon_pates: 'pasta salad with tuna, tomato and cucumber',
  chili_sin_carne: 'vegetarian chili with red kidney beans, tomato sauce and rice',
  bowl_quinoa_pois_chiches: 'buddha bowl with quinoa, chickpeas, zucchini and carrot',
  dinde_patate_douce: 'roasted turkey escalope with roasted sweet potato cubes and green beans',
  wrap_poulet: 'a chicken wrap cut in half with lettuce and tomato',
  saumon_riz_epinards: 'pan seared salmon fillet with rice and sauteed spinach',
  soupe_lentilles: 'orange red lentil soup in a bowl with a slice of bread',
  omelette_champignons: 'mushroom omelette with a green salad',
  steak_pommes_de_terre: 'ground beef steak with boiled potatoes and green beans',
  cabillaud_quinoa: 'baked cod fillet with roasted zucchini, bell pepper and quinoa',
  skyr_banane: 'a bowl of skyr yogurt with sliced banana',
  pancakes_avoine: 'a stack of oat banana pancakes with banana slices',
  smoothie_bowl: 'a smoothie bowl with red berries, banana and granola',
  oeufs_brouilles_epinards: 'scrambled eggs with spinach and toast',
  poke_bowl_saumon: 'poke bowl with salmon, avocado, rice, cucumber and carrot',
  bolognaise_dinde: 'whole wheat spaghetti with turkey bolognese sauce',
  salade_lentilles_feta: 'lentil salad with feta cheese, tomato and cucumber',
  salade_poulet_croquante: 'crunchy chicken salad with lettuce, grated carrot and corn',
  crevettes_riz_legumes: 'sauteed shrimp with rice, bell pepper and zucchini',
  tortilla_pommes_de_terre: 'a spanish potato omelette tortilla slice',
  pita_pizza_legumes: 'a pita pizza with mozzarella, bell pepper and mushrooms',
  poulet_curry_coco: 'chicken in coconut curry sauce served over rice',
  fromage_blanc_fruits: 'a bowl of white cheese with fresh red berries',
  galettes_jambon: 'rice cakes topped with cream cheese and sliced ham',
  smoothie_banane_proteine: 'a glass of banana oat smoothie',
  seche_omelette_blancs_epinards: 'an egg white omelette with spinach and a slice of whole wheat toast',
  seche_fromage_blanc_avoine: 'a bowl of fat free quark with oat flakes and fresh red berries',
  seche_pancakes_proteines: 'a small stack of thin protein oat pancakes topped with blueberries',
  seche_tartine_saumon: 'whole wheat toasts with smoked salmon, white cheese spread and cucumber slices',
  seche_oeufs_brouilles_jambon: 'scrambled eggs with strips of ham, sliced tomato and toast',
  seche_petits_suisses_kiwi: 'a bowl of fresh white cheese with sliced kiwi and oat flakes',
  seche_poulet_courgettes_quinoa: 'sauteed chicken pieces with diced zucchini and quinoa on a plate',
  seche_dinde_haricots_riz: 'a grilled turkey escalope with green beans and basmati rice',
  seche_steak_poivrons: 'a lean ground beef patty with sauteed bell peppers, onion and boiled potatoes',
  seche_salade_thon_oeuf: 'a large salad with tuna, quartered boiled egg, tomato, cucumber and corn',
  seche_bowl_poulet_lentilles: 'a bowl with sliced chicken, lentils, cherry tomatoes, cucumber and a white yogurt sauce',
  seche_pates_thon_tomate: 'whole wheat penne with tuna, tomato sauce, zucchini and basil',
  seche_wrap_poulet: 'a chicken wrap with lettuce and tomato cut in half',
  seche_galette_sarrasin: 'a folded buckwheat crepe with ham, egg and mushrooms, with green salad',
  seche_salade_crevettes_avocat: 'a shrimp salad with avocado, cherry tomatoes, lettuce and corn',
  seche_tofu_saute: 'stir fried tofu cubes with broccoli and red bell pepper and a little rice',
  seche_cabillaud_brocoli: 'baked cod fillet with lemon, steamed broccoli and roasted sweet potato cubes',
  seche_crevettes_wok: 'a wok of shrimps with broccoli, bell pepper and carrot, with rice',
  seche_chili_maigre: 'a bowl of lean beef chili with red kidney beans and bell peppers',
  seche_papillote_lieu: 'white fish fillet on melted leeks in an open parchment paper parcel, with potatoes',
  seche_omelette_champignons: 'a mushroom omelette with green salad and a slice of bread',
  seche_rumsteck_asperges: 'a grilled lean beef steak with green asparagus and boiled potatoes',
  seche_veau_champignons: 'a veal escalope with creamy mushroom sauce and brown rice, parsley',
  seche_truite_fenouil: 'a steamed trout fillet with braised fennel and quinoa, lemon',
  seche_soupe_poulet: 'a bowl of chicken vegetable soup with carrots, leek, zucchini and pasta',
  seche_curry_lentilles_corail: 'a bowl of red lentil curry with spinach and tomato',
  seche_fromage_blanc_cacao: 'a bowl of white cheese mixed with cocoa and topped with raspberries',
  seche_oeufs_durs_radis: 'a halved boiled egg with fresh radishes and a small bowl of herb white cheese dip',
  seche_roules_jambon: 'rolled slices of ham filled with white cheese, with cucumber sticks',
  seche_petits_suisses_pomme: 'a small bowl of fresh white cheese with diced apple and cinnamon',
  seche_galettes_thon: 'puffed rice cakes topped with tuna spread and cucumber slices',
};

mkdirSync('assets/recettes', { recursive: true });
const demandes = process.argv.slice(2);
const ids = demandes.length ? demandes : Object.keys(PLATS);

for (const id of ids) {
  const fichier = `assets/recettes/${id}.jpg`;
  if (!demandes.length && existsSync(fichier)) continue;
  const r = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${COMPTE}/ai/run/@cf/black-forest-labs/flux-1-schnell`,
    {
      method: 'POST',
      headers: { authorization: `Bearer ${JETON}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: `${PLATS[id]}, ${STYLE}`, steps: 6 }),
    },
  );
  const j = await r.json();
  if (!r.ok || !j.result?.image) {
    console.log(id, 'ÉCHEC', r.status, JSON.stringify(j.errors ?? j).slice(0, 200));
    continue;
  }
  writeFileSync(fichier, Buffer.from(j.result.image, 'base64'));
  console.log(id, 'ok', Math.round(Buffer.from(j.result.image, 'base64').length / 1024), 'Ko');
}
