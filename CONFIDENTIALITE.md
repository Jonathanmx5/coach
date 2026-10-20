# Politique de confidentialité de Crunch & Go

Dernière mise à jour : 20 octobre 2026.

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
- **Photo d'un repas** (optionnelle) : la photo est envoyée à un relais Crunch & Go hébergé chez Cloudflare, qui la transmet à un modèle d'IA pour estimer les aliments : l'API Gemini de Google (offre payante, dont les contenus ne servent pas à entraîner les modèles de Google) ou, en secours, un modèle de Cloudflare Workers AI. Le relais ne la conserve pas et la clé d'accès au service de Google n'est jamais dans l'application ; Google peut conserver la demande pendant une durée limitée pour détecter les abus, et le traitement peut avoir lieu hors de l'Union européenne. Quand vous validez le repas, la photo est gardée **uniquement sur votre téléphone** (jamais envoyée dans le cloud) pour pouvoir revoir l'analyse ; seul le résultat que vous validez est ajouté à votre journal en ligne. Trente photos au plus par jour et par personne.
- **Code-barres d'un produit** (optionnel) : le numéro du code-barres que vous scannez est envoyé à Open Food Facts (base collaborative gratuite) pour obtenir les valeurs nutritionnelles. Aucune photo ni information sur vous n'est envoyée.
- **Sauvegarde Excel** (optionnelle) : le fichier est créé sur votre téléphone et rangé à l'endroit que vous choisissez ; il contient vos données de santé en clair. Gardez-le comme vos autres documents personnels. L'import le relit sur votre téléphone puis l'ajoute à votre compte.
- **Notifications** (optionnelles) : rappels de compléments programmés sur votre téléphone.
- **Rapports de plantage** (activés par défaut, désactivables) : si l'application plante ou rencontre une erreur imprévue, un rapport technique est envoyé à Google Firebase Crashlytics pour corriger le problème : la trace de l'erreur, le modèle du téléphone, la version d'Android et celle de l'application, et un identifiant d'installation aléatoire. Le traitement peut avoir lieu hors de l'Union européenne. Vous pouvez couper cet envoi dans Réglages → « Envoyer les rapports de plantage » : le choix est gardé sur votre téléphone et appliqué dès le démarrage de l'application ; plus aucune erreur n'est alors notée, et les rapports pas encore envoyés sont effacés.

## Ce que Crunch & Go ne fait pas

- Aucune vente, location ou cession de vos données.
- Aucune publicité, aucun traçage publicitaire.
- Aucune utilisation de vos données de santé pour autre chose que les fonctions décrites ci-dessus.

## Vos droits

- Vous pouvez retirer l'accès à Health Connect à tout moment dans les réglages de Health Connect.
- Vous pouvez modifier votre profil dans l'application.
- **Suppression du compte et des données** : dans l'application, Réglages → « Supprimer mon compte et mes données ». Cela efface définitivement votre profil, vos repas, activités, pesées, mensurations, séances, eau, compléments, plannings et réglages (côté serveur), les photos de progression et de repas de votre téléphone (copies temporaires comprises) et votre compte de connexion. Votre compte Google peut vous être redemandé pour confirmer : tant qu'il ne l'est pas, rien n'est effacé. Sans l'application (par exemple si elle est désinstallée), ouvrez une demande sur la page GitHub du projet en indiquant l'adresse e-mail de votre compte Google : vos données seront effacées.
- **Consentements** : l'envoi d'une photo de repas à l'analyse et l'envoi de votre position approximative à Open-Meteo ne se font qu'après votre accord, demandé la première fois. Vous pouvez retirer l'accord pour les photos dans Réglages ; l'y redonner affiche à nouveau le texte complet. Les rapports de plantage se coupent au même endroit.
- Contact : via la page GitHub du projet, https://github.com/Jonathanmx5/coach.

Crunch & Go ne remplace pas un avis médical.
