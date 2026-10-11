# Relais photo de repas (Cloudflare Worker)

Reçoit la photo d'un repas depuis l'application, vérifie le jeton Firebase de l'utilisateur, applique des plafonds journaliers, interroge un modèle de vision gratuit de Cloudflare Workers AI et renvoie la liste des aliments estimés. L'image n'est ni enregistrée ni journalisée.

- `POST /analyse` — corps : image JPEG (1,5 Mo max) ; `Authorization: Bearer <jeton Firebase>`.
- Réponse : `{"aliments":[{"nom","grammes","kcal","proteines","glucides","lipides"}]}` ou `{"erreur":"auth|quota|taille|illisible|ia"}` (401, 429, 413, 422, 502).
- Plafonds (par jour UTC) : 15 photos par utilisateur et 150 au total, pour rester dans le quota gratuit de Workers AI (environ 10 000 neurones par jour). Réglables dans `wrangler.toml`.
- Le modèle est interchangeable (`MODELE`). Le format de l'entrée est dans `src/analyse.js` (`entreeModele`).

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

Puis compiler l'application avec l'adresse obtenue :

```bash
flutter build apk --dart-define=RELAIS_URL=https://coach-relais.<compte>.workers.dev
```

Sans `RELAIS_URL`, l'entrée « Photo du repas » n'apparaît pas dans l'application.

## Évaluer la qualité

Rassembler une vingtaine de photos de vrais repas pesés (`x.jpg` + `x.json` avec `{"kcal": 650}`), puis :

```bash
RELAIS_URL=https://… JETON=<jeton Firebase> node eval/evaluer.js ./photos
```
