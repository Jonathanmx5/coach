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
  tartine_avocat: 'toasts with smashed avocado and a halved soft boiled egg',
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
  curry_pois_chiches: 'chickpea and spinach curry with coconut milk and rice',
  cabillaud_quinoa: 'baked cod fillet with roasted zucchini, bell pepper and quinoa',
  pomme_amandes: 'a red apple and a handful of almonds',
  skyr_banane: 'a bowl of skyr yogurt with sliced banana',
  houmous_legumes: 'hummus dip with carrot and cucumber sticks',
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
  galettes_cacahuete: 'rice cakes spread with peanut butter',
  smoothie_banane_proteine: 'a glass of banana oat smoothie',
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
