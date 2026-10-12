# Relais photo de repas (Cloudflare Worker)

Reçoit la photo d'un repas depuis l'application, vérifie le jeton Firebase de l'utilisateur, applique des plafonds journaliers, interroge un modèle de vision (Google Gemini si une clé est configurée, sinon un modèle gratuit de Cloudflare Workers AI) et renvoie la liste des aliments estimés. L'image n'est ni enregistrée ni journalisée.

- `POST /analyse` — corps : image JPEG (1,5 Mo max) ; `Authorization: Bearer <jeton Firebase>`.
- Réponse : `{"aliments":[{"nom","grammes","kcal","proteines","glucides","lipides"}]}` ou `{"erreur":"auth|quota|taille|illisible|ia"}` (401, 429, 413, 422, 502).
- Plafonds (par jour UTC) : 8 photos par utilisateur et 500 au total (une photo coûte environ 10 neurones, le quota gratuit de Workers AI est de 10 000 par jour). Réglables dans `wrangler.toml`.
- Le modèle est interchangeable (`MODELE`) : Llama 3.2 11B Vision par défaut ; si sa réponse est illisible (texte libre au lieu de JSON, constaté sur des photos de test) ou en panne, `MODELE_SECOURS` (Llama 4 Scout 17B) prend le relais. Le format de l'entrée est dans `src/analyse.js` (`entreeModele`).

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

## Évaluer la qualité

Rassembler une vingtaine de photos de vrais repas pesés (`x.jpg` + `x.json` avec `{"kcal": 650}`), puis :

```bash
RELAIS_URL=https://… JETON=<jeton Firebase> node eval/evaluer.js ./photos
```

## App Check (preuve que l'appel vient de la vraie application)

L'application envoie un jeton App Check (Play Integrity) dans l'en-tête `X-Firebase-AppCheck`. Le relais le vérifie selon `APP_CHECK` dans `wrangler.toml` :

- `off` (défaut) : rien n'est vérifié ;
- `observe` : les appels sans preuve valide sont notés dans les journaux (`wrangler tail`) mais acceptés ;
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
