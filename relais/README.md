# Relais photo de repas (Cloudflare Worker)

Reçoit la photo d'un repas depuis l'application, vérifie le jeton Firebase de l'utilisateur, applique des plafonds journaliers, interroge un modèle de vision (Google Gemini si une clé est configurée, sinon un modèle gratuit de Cloudflare Workers AI) et renvoie la liste des aliments estimés. L'image n'est ni enregistrée ni journalisée.

- `POST /analyse` — corps : `multipart/form-data` avec les parties `image` (JPEG, 1,5 Mo max) et `indice` (précision facultative, 200 caractères utiles) ; `Authorization: Bearer <jeton Firebase>`. L'ancien format (image brute dans le corps, précision dans `?indice=`) reste accepté pour les applications pas encore à jour. Seul le JPEG est accepté (octets magiques `FF D8 FF`) ; un corps annoncé trop gros (`Content-Length`) est refusé sans être lu.
- Réponse : `{"aliments":[{"nom","grammes","kcal","proteines","glucides","lipides"}],"restantes":n}` (`restantes` : photos encore permises aujourd'hui) ou `{"erreur":"auth|quota|taille|format|illisible|ia"}` (401, 429, 413, 415, 422, 502, 503). Le relais répond toujours en JSON, même en cas d'erreur imprévue ou de panne de KV (503).
- Plafonds (par jour UTC) : 30 photos par utilisateur et 500 au total, réglables dans `wrangler.toml`. Ce plafond global est un garde-fou grossier : le coût réel d'une photo dépend du modèle qui répond (Gemini, principal, secours) et de la longueur de la réponse ; il est à recalculer avec l'usage journalisé (voir plus bas). L'unité est prise avant l'appel au modèle et rendue si aucune réponse exploitable n'est produite (panne, réponse illisible, délai dépassé). Quand le quota de neurones de Workers AI est épuisé, le relais répond 429 `{"erreur":"quota","raison":"service"}` plutôt qu'une panne. KV n'étant pas atomique, une rafale de N requêtes simultanées peut dépasser un plafond de N-1.
- Délais : 15 s au plus pour Gemini, 35 s au total pour une analyse (l'application abandonne à 45 s) ; le modèle de secours n'est pas lancé s'il reste moins de 12 s. Une réponse de Gemini coupée (`finishReason` autre que `STOP`, par exemple `MAX_TOKENS`) est refusée et le relais passe au modèle suivant ; la réflexion de Gemini est limitée (`thinkingConfig`).
- Le modèle est interchangeable (`MODELE`) : Llama 3.2 11B Vision par défaut ; si sa réponse est illisible (texte libre au lieu de JSON, constaté sur des photos de test) ou en panne, `MODELE_SECOURS` (Llama 4 Scout 17B) prend le relais. Le format de l'entrée est dans `src/analyse.js` (`entreeModele`).

## Journal d'usage

Chaque analyse écrit une ligne JSON dans les journaux du Worker (`npx wrangler tail`) : statut, durée, et pour chaque modèle essayé son nom, les jetons d'entrée et de sortie (et de réflexion pour Gemini) et l'issue. Par exemple :

```json
{"analyse":200,"ms":6200,"essais":[{"modele":"gemini-3.8-flash","entree":1300,"sortie":420,"reflexion":60,"ok":true}]}
```

Ni l'image, ni la précision, ni la réponse, ni l'identifiant de l'utilisateur n'y figurent. Ces mesures servent à recalculer les plafonds avec le barème réel de chaque fournisseur.

## Tests

```bash
npm test        # aucun service externe nécessaire
```

## Déploiement (une fois)

```bash
npm install
npx wrangler login
npx wrangler kv namespace create LIMITES     # copier l'id dans wrangler.toml
# Accepter la licence du modèle Meta (une seule fois) : appeler le modèle avec
# {"prompt":"agree"} depuis le tableau de bord Workers AI.
npx wrangler deploy
```

Adresse actuelle : `https://coach-relais.coach-relais.workers.dev`. Compiler l'application avec :

```bash
flutter build apk --dart-define=RELAIS_URL=https://coach-relais.<compte>.workers.dev
```

Sans `RELAIS_URL`, l'entrée « Photo du repas » n'apparaît pas dans l'application.

## Évaluer et comparer les modèles

Prendre une vingtaine de **vrais repas pesés** : photographier l'assiette, noter le poids total et les calories (balance de cuisine, étiquettes). Dans un dossier, pour chaque repas, `x.jpg` et `x.json` :

```json
{"kcal": 650, "grammes": 480}
```

(`grammes` : poids total du repas, facultatif.) Puis :

```bash
cd relais
node eval/comparer.js ./photos
```

Le script lance un petit worker d'évaluation (`wrangler dev --remote`, quota gratuit de Workers AI, ni jeton ni plafond) et compare Llama 3.2 11B, Llama 4 Scout et Mistral Small 3.1 ; Gemini s'ajoute si `GEMINI_API_KEY` est défini dans l'environnement. Il affiche, par modèle : la part de réponses lisibles, l'erreur médiane sur les calories, la part des repas à ±20 %, l'erreur sur le poids, la part des repas dont le poids pesé tombe dans la fourchette annoncée, et la durée moyenne. Pour tester d'autres modèles : `node eval/comparer.js ./photos "@cf/meta/llama-4-scout-17b-16e-instruct,gemini"`.

`evaluer.js` mesure, lui, le relais déployé (`RELAIS_URL` et `JETON` Firebase), tel que l'application l'appelle.

## Garde-fous sur la réponse du modèle

- Le relais lit du JSON, du JSON sans accolades extérieures (fréquent avec Llama 3.2), du JSON coupé en route, et même une liste à puces.
- Chaque aliment peut porter une fourchette de quantité (`grammes_min`, `grammes_max`), gardée seulement si elle encadre l'estimation.
- Pour un aliment sans ambiguïté (riz, pâtes, poulet, œuf, pain...), si la densité calorique annoncée s'écarte de plus de 25 % de `src/referentiel.js`, les apports sont recalculés avec ce tableau (les grammes restent ceux du modèle). Liste blanche stricte : le nom doit être exactement un mot-clé, aux adjectifs neutres près (cuit, nature, vapeur, grillé, blanc) ; « Pain au chocolat », « Jambon cru », « Poulet pané » ou un plat composé ne sont jamais corrigés. Les valeurs lues sur une étiquette (`"source": "etiquette"`) ne le sont pas non plus. Ce tableau est un ordre de grandeur, à valider avec la série de repas pesés.
- L'alcool compte 7 kcal par gramme (champ `alcool`) ; sans ce champ, les calories d'une bière ou d'un vin ne sont pas ramenées à celles des seuls glucides.
- Liste à puces : seules les puces du premier niveau sont des aliments, une macro n'est rattachée qu'à l'aliment moins indenté au-dessus d'elle ; fibres, sel et poids total sont ignorés, et la lecture s'arrête au récapitulatif « Total ».
- Confiance par défaut 0,5 (sous le seuil « à vérifier » de l'application), plafonnée à 0,5 si les grammes manquent et à 0,3 pour un aliment sans calories ni macros. Si aucun aliment n'a de valeur, la réponse est illisible (modèle de secours, puis 422).

## App Check (preuve que l'appel vient de la vraie application)

L'application envoie un jeton App Check (Play Integrity) dans l'en-tête `X-Firebase-AppCheck`. Le relais le vérifie selon `APP_CHECK` dans `wrangler.toml` :

- `off` : rien n'est vérifié ;
- `observe` (réglage actuel, avec `PROJECT_NUMBER` renseigné) : les appels sans preuve valide sont notés dans les journaux (`wrangler tail`) mais acceptés ;
- `enforce` : ils sont refusés (401).

Mise en route : Console Firebase → App Check → enregistrer l'application Android avec Play Integrity ; renseigner `PROJECT_NUMBER` (numéro du projet, dans les paramètres du projet) ; passer `APP_CHECK` à `observe`, puis à `enforce` **seulement une fois l'application distribuée par le Play Store** : un APK installé à la main (GitHub) n'a pas de preuve Play Integrity et serait refusé.

## Google Gemini (recommandé pour la précision)

Le relais utilise Gemini quand le secret `GEMINI_API_KEY` existe ; au moindre échec (clé refusée, quota, panne, réponse illisible) il repasse automatiquement au modèle de Workers AI. `FOURNISSEUR = "workers"` dans `wrangler.toml` force Workers AI.

1. Créer un projet et une clé dans [Google AI Studio](https://aistudio.google.com/apikey), puis **activer la facturation** du projet (offre payante) : avec l'offre gratuite, Google peut utiliser les photos pour améliorer ses produits, ce que la politique de confidentialité exclut.
2. Enregistrer la clé comme secret (la valeur est demandée au clavier, jamais écrite dans un fichier) :

   ```bash
   cd relais
   npx wrangler secret put GEMINI_API_KEY
   npx wrangler deploy
   ```

3. Restreindre la clé dans la console Google Cloud (API Generative Language uniquement) et fixer un budget d'alerte.

Le modèle se règle avec `GEMINI_MODELE` (`gemini-3.8-flash` par défaut ; `gemini-3.5-flash-lite` ou `gemini-3.1-flash-lite` sont moins chers et moins précis). Ordre de grandeur : une photo représente environ 1 000 à 2 000 jetons en entrée, soit quelques millièmes d'euro avec un modèle Flash (tarifs à vérifier sur la page des prix de Google).
