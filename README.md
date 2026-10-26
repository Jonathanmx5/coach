# Crunch & Go

Application Android de coaching sportif et alimentaire pour débutants. Nom de l'application : « Crunch & Go » (le dépôt et le code s'appellent encore `coach`). Français uniquement.

## Ce que fait l'application

- **Profil et repères** : questionnaire de départ (objectif, taille, poids, mode de vie, entraînement), calories et protéines cibles avec des garde-fous de santé.
- **Journal** : photo du repas ou d'un produit analysée par IA (via le relais) avec le « carton » du coach (vert, orange, rouge) selon ton objectif, ou code-barres (Open Food Facts) ; l'IA qui doute demande une précision. Chaque repas se rouvre avec son analyse et sa photo (gardée sur le téléphone), et se corrige (portions, moment). Total de la journée, bilan énergétique du jour (mangé moins dépensé).
- **Santé connectée** : lecture seule de Health Connect (pas, cœur, sommeil, calories…), donc Mi Fitness, Zepp Life, Google Fit, Samsung Health, etc. Rien n'est copié dans le cloud.
- **Poids** : IMC coloré, courbe avec projection à 5 jours, mensurations, masse grasse, photos de progression (appareil ou bibliothèque, à la date de ton choix, gardées sur le téléphone) et comparaison par superposition.
- **Entraînement** : séances à la maison (avec le matériel qu'on possède), en salle, course à pied (programme de 8 semaines) et marche ; séance guidée avec minuteur et voix ; progression automatique.
- **Récupération** : score du matin (sommeil, variabilité cardiaque, ressenti) et routines d'étirements.
- **Bien-être** : hydratation (poids, effort, météo), rappels de compléments, séries de jours.
- **Repas de la semaine** : recettes, planning selon la cible calorique, liste de courses par rayon.
- **Widgets Android** : anneaux du jour avec ajout d'eau, hydratation (2x2), repas avec accès direct à la photo ; à ajouter depuis le sélecteur de widgets du téléphone.
- **Sauvegarde** : dans Réglages, enregistrement de tout l'historique (repas, activités, pesées, mensurations, eau, compléments, séances) dans un fichier Excel, et import pour le restaurer ou y ajouter des lignes à la main.
- **Confort** : interface en verre givré (Liquid Glass), thème clair, sombre ou automatique au choix, texte agrandi pris en charge, anneaux décrits aux lecteurs d'écran.
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

## Crédits

- Photos de démonstration des exercices (`app/assets/exercices/`) : jeu libre de droits [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (licence Unlicense, domaine public), réduites à 480 px. Le script `app/tool/telecharger_exercices.mjs` les récupère.
- Valeurs nutritionnelles de référence du relais (`relais/donnees/ciqual.json`) et recherche d’aliments de l’appli (`app/assets/ciqual.json`) : ANSES, Table de composition nutritionnelle des aliments Ciqual 2020 ([doi:10.5281/zenodo.4770600](https://doi.org/10.5281/zenodo.4770600)), licence [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) ; extrait (énergie et macronutriments pour 100 g) converti en JSON.
- Photos des recettes (`app/assets/recettes/`) : illustrations générées par IA (modèle flux-1-schnell, licence Apache 2.0).
