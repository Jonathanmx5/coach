# Politique de confidentialité de Crunch & Go

Dernière mise à jour : 9 octobre 2026.

Crunch & Go est une application Android de coaching sportif et alimentaire. Cette page explique quelles données elle utilise, pourquoi, et où elles sont conservées.

## Données de compte et de profil

- **Compte Google** : sert uniquement à vous identifier et à sauvegarder votre profil.
- **Profil** (objectif, sexe, année de naissance, taille, poids, type de vie, préférences d'entraînement, réponse à la question santé, présence d'une montre) : stocké dans Google Firebase (Cloud Firestore), **hébergé en Europe**. Vous seul pouvez y accéder.

## Données de santé (Health Connect)

Si vous l'autorisez, Crunch & Go **lit** dans Health Connect :

- activité : pas, distance, étages, calories actives et totales, séances d'exercice ;
- sommeil : durée et phases (léger, profond, paradoxal, éveil) ;
- cœur et respiration : fréquence cardiaque, fréquence cardiaque au repos, variabilité, saturation en oxygène, fréquence respiratoire ;
- corps : poids, masse grasse.

Ces données servent à :

- afficher votre journée et vos courbes dans l'application ;
- ajuster vos repères caloriques avec les calories réellement brûlées ;
- mettre à jour votre poids dans votre profil.

**Elles restent sur votre téléphone.** Crunch & Go ne les copie pas sur un serveur. Seul le poids importé est enregistré dans votre profil, comme une saisie manuelle. Crunch & Go n'écrit rien dans Health Connect.

## Autres données

- **Journal, entraînement, eau, compléments, mensurations** : enregistrés dans votre compte (Firestore, Europe), visibles de vous seul. Crunch & Go ne donne aucune dose de complément.
- **Photos de progression** : conservées **uniquement sur votre téléphone**, jamais envoyées.
- **Localisation approximative** (optionnelle) : si vous activez « Adapter à la météo », votre position, arrondie à environ 10 km, est envoyée au service Open-Meteo pour obtenir la température du jour. Elle n'est pas enregistrée.
- **Codes-barres** : le code d'un produit scanné est envoyé à Open Food Facts pour retrouver ses valeurs nutritionnelles.
- **Photo d'un repas** (optionnelle) : la photo est envoyée à un relais Crunch & Go hébergé chez Cloudflare, qui la transmet à un modèle d'IA de Cloudflare Workers AI pour estimer les aliments. Elle n'est ni enregistrée ni conservée ; seul le résultat que vous validez est ajouté à votre journal. Quinze photos au plus par jour et par personne.
- **Notifications** (optionnelles) : rappels de compléments programmés sur votre téléphone.

## Ce que Crunch & Go ne fait pas

- Aucune vente, location ou cession de vos données.
- Aucune publicité, aucun traçage publicitaire.
- Aucune utilisation de vos données de santé pour autre chose que les fonctions décrites ci-dessus.

## Vos droits

- Vous pouvez retirer l'accès à Health Connect à tout moment dans les réglages de Health Connect.
- Vous pouvez modifier votre profil dans l'application et demander la suppression de votre compte et de toutes vos données.
- Contact : via la page GitHub du projet, https://github.com/Jonathanmx5/coach.

Crunch & Go ne remplace pas un avis médical.
