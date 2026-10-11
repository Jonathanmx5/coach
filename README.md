# Coach

Application Android de coaching sportif et alimentaire pour débutants. Nom de travail : « Coach ». Français uniquement.

## Ce que fait l'application

- **Profil et repères** : questionnaire de départ (objectif, taille, poids, mode de vie, entraînement), calories et protéines cibles avec des garde-fous de santé.
- **Journal** : repas saisis, produits scannés (Open Food Facts), photo du repas analysée par IA (via le relais), activités, bilan énergétique du jour (mangé moins dépensé).
- **Santé connectée** : lecture seule de Health Connect (pas, cœur, sommeil, calories…), donc Mi Fitness, Zepp Life, Google Fit, Samsung Health, etc. Rien n'est copié dans le cloud.
- **Poids** : IMC coloré, courbe avec projection à 5 jours, mensurations, masse grasse, photos de progression (gardées sur le téléphone) et comparaison par superposition.
- **Entraînement** : séances à la maison (avec le matériel qu'on possède), en salle, course à pied (programme de 8 semaines) et marche ; séance guidée avec minuteur et voix ; progression automatique.
- **Récupération** : score du matin (sommeil, variabilité cardiaque, ressenti) et routines d'étirements.
- **Bien-être** : hydratation (poids, effort, météo), rappels de compléments, séries de jours.
- **Repas de la semaine** : recettes, planning selon la cible calorique, liste de courses par rayon.
- **Hors-ligne** : les données sont gardées en cache et envoyées au retour du réseau.

## Organisation du dépôt

- `app/` : application Flutter (Android).
- `relais/` : relais Cloudflare Worker pour la photo de repas (voir `relais/README.md`).
- `firebase/` : règles Firestore et leurs tests.
- `docs/superpowers/` : spécifications et plans.
- `CONFIDENTIALITE.md` : politique de confidentialité.
- `PUBLICATION.md` : signature, publication GitHub et Play Store.

## Développer

```bash
cd app
flutter pub get
flutter test
flutter run
```

La configuration Firebase du dépôt (`google-services.json`, `firebase_options.dart`) n'est pas secrète : ces identifiants sont publics par conception, la sécurité repose sur les règles Firestore (`firestore.rules`) et sur l'authentification.

Pour activer la photo de repas, déployer le relais puis compiler avec `--dart-define=RELAIS_URL=<adresse>`.

## Licence

Aucune licence : le code est visible, mais tous droits sont réservés. Pour le réutiliser, demander l'accord de l'auteur.
