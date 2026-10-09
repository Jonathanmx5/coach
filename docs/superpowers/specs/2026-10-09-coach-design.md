# Coach : conception (V1)

> Nom de travail : **Coach**. Le nom public sera choisi avant la publication sur le Play Store.
> Date : 2026-10-09. Statut : en relecture.

## 1. Intention

**Produit :** application Android grand public de coaching sportif et alimentaire, pour les débutants.

**Promesse :** *la photo remplace le comptage de calories*, et tout reste simple.
- L'utilisateur photographie son assiette. L'appli répond en langage simple (« Bien pour ton objectif », « Un peu léger en protéines, ajoute un yaourt ce soir »), sans imposer de chiffres.
- Côté sport, l'appli propose des programmes tout faits, adaptés au profil, sans réglages compliqués.

**Critère de réussite :** un débutant installe l'appli, répond au questionnaire et, en moins de 2 minutes, il a un programme adapté à son lieu d'entraînement et peut photographier son premier repas.

**Décisions prises :**

| Sujet | Décision |
|---|---|
| Public | Grand public |
| Plateforme | Android uniquement (technologie compatible iPhone plus tard) |
| Modèle économique | Gratuit au lancement avec plafond de photos ; abonnement plus tard (non construit en V1) |
| Données | Compte Google + synchronisation cloud |
| Entraînement | Salle, maison, course, marche |
| Course / marche | Plans guidés au minuteur vocal + lecture Health Connect, **pas de GPS** |
| Alimentation | Analyse photo + conseils + bilans (pas d'idées de repas, pas de menus) |
| IA de vision | Modèle **gratuit** : Cloudflare Workers AI (quota gratuit) |
| Langue | Français uniquement, textes séparés du code |
| Distribution | Dépôt GitHub **public** + APK en releases, puis Google Play |

**Hors périmètre V1 :** abonnement et paiement, iPhone, GPS, idées de repas ou menus, recettes, traductions, vidéos d'exercices, fonctions sociales.

## 2. Architecture

```
┌──────────────────────────┐        ┌───────────────────────────┐
│  Appli Flutter (Android) │──────▶ │ Firebase (forfait Spark)   │
│  Profil · Entraînement   │        │  Auth Google               │
│  Repas · Suivi · Compte  │        │  Firestore (Europe)        │
│  Contenu sportif intégré │        │  Crashlytics               │
└────────────┬─────────────┘        └───────────────────────────┘
             │ photo + jeton Firebase
             ▼
┌──────────────────────────┐        ┌───────────────────────────┐
│ Relais Cloudflare Worker │──────▶ │ Workers AI (modèle vision) │
│  vérif. jeton · plafonds │        └───────────────────────────┘
│  D1 : compteurs du jour  │
└──────────────────────────┘
```

**Pourquoi ce montage :** tout est gratuit et sans carte bancaire. Les fonctions serveur Firebase exigent le forfait payant Blaze, d'où le relais sur Cloudflare.

### 2.1 Appli Flutter

Modules indépendants, chacun avec sa logique testable séparée de l'interface :

- **profil** : questionnaire, calcul des besoins, garde-fous.
- **entrainement** : bibliothèque, générateur de programmes, séance guidée, progression, historique.
- **repas** : capture, file d'attente hors-ligne, appel au relais, résultat, correction, bilans.
- **suivi** : poids, Health Connect.
- **compte** : connexion, déconnexion, suppression du compte, avis de mise à jour.

### 2.2 Firebase

- **Auth** : connexion Google uniquement.
- **Firestore** : région européenne, avec la persistance hors-ligne activée. Règles : un utilisateur ne lit et n'écrit que sous `users/{uid}`.
- **Crashlytics** : remontée des plantages.

Structure des données :

```
users/{uid}                     profil, repères calculés, réglages
users/{uid}/weights/{date}      poids
users/{uid}/sessions/{id}       séance faite : date, type, exercices, charges, ressenti
users/{uid}/meals/{id}          repas : date, moment, précision, résultat d'analyse (pas de photo)
users/{uid}/program/current     programme en cours (généré), semaine courante
```

### 2.3 Relais Cloudflare Worker

Un seul point d'entrée, `POST /analyse-repas`, qui :

1. vérifie le jeton Firebase (signature avec les clés publiques Google, `aud` = projet, `iss`, expiration) ;
2. vérifie le **plafond utilisateur** (3 analyses par jour par défaut) et le **plafond global** (calé sous le quota gratuit Workers AI), avec des compteurs D1 par `(uid, date UTC)` ;
3. appelle le modèle de vision avec la photo, l'objectif, les repères du jour et le résumé des repas déjà mangés ;
4. valide la réponse JSON, avec un nouvel essai en cas de réponse mal formée ;
5. ne décompte le quota qu'en cas d'analyse réussie d'un vrai repas.

Plafonds et nom du modèle sont des **réglages** du Worker (variables d'environnement), modifiables sans republier l'appli. Les secrets restent dans les secrets Cloudflare, jamais dans le dépôt. Le relais ne stocke **aucune photo**.

### 2.4 Contenu sportif

Fichiers JSON intégrés à l'appli et versionnés avec elle : exercices, gabarits de programmes, plans course/marche.

## 3. Profil et besoins

**Questionnaire (un écran par question, avec barre de progression, environ 1 minute) :**

1. Objectif : perdre du poids / prendre du muscle / garder la forme / reprendre le sport
2. Sexe, âge
3. Taille, poids
4. Type de vie : assis toute la journée / un peu actif / actif / très actif (avec exemples)
5. Types d'entraînement (choix multiple) : salle, maison, course, marche
6. Niveau : débutant / reprise / régulier
7. Jours par semaine (2 à 5), durée d'une séance (20 / 30 / 45 / 60 min)
8. Grossesse ou problème de santé particulier ? (oui / non)
9. Connexion Google, puis affichage du programme

**Calcul :**
- Dépense de base (Mifflin-St Jeor) : homme `10·kg + 6,25·cm − 5·âge + 5`, femme `… − 161`.
- Facteur selon le type de vie : 1,2 / 1,375 / 1,55 / 1,725.
- Ajustement selon l'objectif : perte −15 % (déficit plafonné à 500 kcal), muscle +10 %, forme et reprise 0 %.
- Planchers : 1 200 kcal (femme), 1 500 kcal (homme).
- Repère de protéines : 1,6 g/kg (perte, muscle), 1,2 g/kg (forme, reprise).
- **Jour d'entraînement** : le repère est relevé d'une estimation de la dépense de la séance.

**Garde-fous :**
- Moins de 18 ans : accès refusé, avec un message bienveillant.
- IMC < 18,5 avec l'objectif « perdre du poids » : objectif refusé, l'appli propose « garder la forme ».
- Grossesse ou problème de santé : conseil de consulter un médecin, objectif « perdre du poids » désactivé.
- La mention « ne remplace pas un avis médical » apparaît dans le questionnaire et les réglages.
- Le ton n'est jamais culpabilisant.

**Ensuite :** un rappel hebdomadaire de pesée, avec recalcul automatique des repères. Le profil est modifiable à tout moment.

## 4. Entraînement

**Bibliothèque :** 60 à 80 exercices (maison poids du corps, salle machines et haltères). Chaque exercice a : id, nom, lieu, muscles, matériel, niveau, mode (répétitions ou durée), 3-4 étapes, erreurs fréquentes, visuels.

**Visuels :** la base libre *free-exercise-db* (images de début et de fin de mouvement, alternées en boucle). **À vérifier avant adoption :** licence, qualité et couverture des exercices retenus. Les textes sont réécrits en français.

**Plans course/marche (écrits à la main) :** « Débuter la course » sur 8 semaines (objectif 30 min continues), « Marche active » sur 6 semaines, et une variante pour coureurs réguliers. Chaque séance est une suite de phases `{type: course|marche|échauffement|retour au calme, durée}`.

**Générateur de programme (à règles, déterministe) :**
- Structure selon les jours de renforcement : corps entier pour 2-3 jours, haut/bas du corps pour 4 jours et plus.
- Choix des exercices selon le lieu, le niveau et le matériel. La variété est assurée en évitant de répéter le même exercice deux séances de suite.
- Paramètres selon l'objectif : perte = circuits, 12-15 répétitions, 30-45 s de repos ; muscle = 3-4 séries de 8-12 répétitions, 90 s de repos ; forme et reprise = 2-3 séries de 10-12 répétitions, 60 s de repos.
- Durée de séance respectée en ajustant le nombre d'exercices.
- **Plusieurs types choisis** : les jours sont répartis (par exemple 3 jours avec renforcement + course = 2 renforcement + 1 course).
- Le résultat est une semaine type répétée sur 4 à 8 semaines, puis un nouveau cycle est proposé.

**Séance guidée :**
- Renforcement : un écran par exercice (visuel, consignes, compteur de séries, saisie de la charge en salle), puis un minuteur de repos annoncé **par la voix** (synthèse vocale française) et par vibration.
- Course/marche : phases annoncées par la voix, fonctionnement **écran éteint** grâce à un service Android au premier plan avec une notification.
- Fin de séance : « Trop facile / Bien / Difficile », puis enregistrement dans Firestore.

**Progression :**
- Trop facile : +2 répétitions, ou +2,5 kg en salle à la séance suivante.
- Bien : on garde les paramètres, avec +1 répétition si toutes les séries ont été complétées.
- Difficile : on garde les paramètres, et on allège après deux séances difficiles de suite.
- Course : on passe à la semaine suivante si c'était bien ou trop facile, on répète la semaine si c'était difficile.

**Historique :** liste des séances, séances de la semaine par rapport à l'objectif, série de semaines tenues.

## 5. Repas photo

**Capture :** appareil photo ou galerie, moment deviné d'après l'heure (modifiable), précision facultative en texte. La photo est réduite à 768 px maximum (côté long) en JPEG avant l'envoi.

**Réponse attendue du modèle (validée par le relais) :**

```json
{
  "est_un_repas": true,
  "aliments": [{"nom": "riz blanc", "portion": "environ 150 g"}],
  "estimation": {"kcal": 620, "proteines_g": 28, "glucides_g": 80, "lipides_g": 18},
  "verdict": "bien | correct | a_equilibrer",
  "conseil": "Une phrase, ton bienveillant.",
  "confiance": "haute | moyenne | basse"
}
```

**Résultat :** le verdict et le conseil en grand, puis la liste des aliments. Le bouton « Voir les détails » affiche les chiffres, libellés comme des estimations. **Une correction gratuite par repas :** le texte de correction est renvoyé avec la photo encore en mémoire sur le téléphone. Si la confiance est basse, l'appli invite à ajouter une précision.

**Hors-ligne :** la photo est gardée sur le téléphone avec le statut « en attente ». Elle est analysée au retour du réseau, puis supprimée.

**Bilans (calculés sur le téléphone, sans IA) :**
- Jour : jauge d'énergie (sous / dans / au-dessus du repère, avec une tolérance de ±10 %), jauge de protéines (OK / à compléter) et conseil pour le prochain repas.
- Semaine : nombre de repas « bien », tendance et séances faites.

**Choix du modèle :** un modèle de vision du catalogue Workers AI (par exemple Llama 3.2 11B Vision). Le choix final se fait sur le **jeu d'évaluation** (§8). Le modèle est un réglage, remplaçable par un modèle payant plus tard.

## 6. Suivi

**Remplacé par `2026-10-09-sante-connectee-design.md`** (montre connectée demandée dès le questionnaire, lecture élargie à Health Connect, sommeil compris, ajustement des repères par les calories mesurées). Ce chantier est avancé avant l'étape 2.

## 7. Erreurs

| Situation | Comportement |
|---|---|
| Hors-ligne | Séances, historique et bilans fonctionnent ; photos mises en attente |
| Plafond utilisateur atteint | « Tu as utilisé tes 3 analyses du jour, à demain ! » |
| Plafond global atteint | « Service très demandé aujourd'hui, réessaie demain » |
| Pas un repas | « Je ne vois pas de repas sur cette photo », quota non décompté |
| Relais ou modèle en erreur | Message clair + nouvel essai ; photo conservée en attente |
| Health Connect absent ou refusé | Lien d'installation ; l'écran Suivi marche avec le poids seul |
| Plantage | Remonté par Crashlytics |

Aucune erreur technique brute n'est montrée à l'utilisateur.

## 8. Tests

- **Logique (tests unitaires Dart)** : calcul des besoins, planchers, garde-fous, générateur de programmes (dont la répartition entre plusieurs types et le respect de la durée), progression, bilans.
- **Interface** : tests de widgets pour le questionnaire et la séance guidée.
- **Relais (tests locaux du Worker)** : vérification du jeton, plafonds utilisateur et global, validation et nouvel essai sur le JSON, cas « pas un repas ».
- **Règles Firestore** : tests sur l'émulateur (aucun accès aux données d'un autre utilisateur).
- **Jeu d'évaluation IA** : une vingtaine de photos de repas variés, avec les aliments et l'ordre de grandeur attendus. On compare les modèles disponibles avant le lancement.
- **À la fin de chaque étape** : test manuel sur le téléphone.

## 9. Livraison et distribution

**Étapes, chacune utilisable sur le téléphone :**
1. **Socle** : projet Flutter, Firebase, connexion Google, questionnaire, calcul des besoins.
2. **Entraînement** : bibliothèque, générateur, séance guidée avec voix, progression, historique.
3. **Repas photo** : relais Cloudflare, analyse, résultat, correction, file hors-ligne, bilans.
4. **Suivi et publication** : Health Connect, poids, suppression du compte, avis de mise à jour, release GitHub, puis Play Store.

**GitHub (d'abord) :**
- Dépôt **public**. **Pas de licence en V1** : tous droits réservés par défaut, à reconsidérer.
- Releases avec un APK signé, gardées **en brouillon jusqu'à vérification** sur le téléphone.
- L'appli consulte la dernière release au démarrage et affiche « Nouvelle version disponible » avec un lien. **Pas** d'installation automatique (permission `REQUEST_INSTALL_PACKAGES` exclue).
- La **clé de signature** est hors du dépôt et sauvegardée. Elle sera réutilisée pour le Play Store, et son empreinte SHA-1 est enregistrée dans Firebase pour la connexion Google.
- Aucun secret dans le dépôt (les secrets Cloudflare sont dans le Worker ; la configuration Firebase de l'appli n'est pas secrète).

**Google Play (ensuite) :**
- Compte développeur à 25 $ (paiement unique).
- Nouveau compte personnel : test fermé avec **au moins 12 testeurs pendant 14 jours** avant la production.
- Documents : politique de confidentialité en ligne, formulaire « sécurité des données », déclaration Health Connect, déclaration des applis santé, suppression du compte dans l'appli et via un lien web, classification du contenu.
- Le contrôle des releases GitHub est retiré de la version Play.

## 10. Points ouverts (à trancher pendant l'implémentation)

- Licence et qualité de *free-exercise-db*.
- Fonctionnement de Health Connect hors Play Store.
- Modèle de vision retenu et nombre réel de photos par jour avec le quota gratuit (mesuré sur le jeu d'évaluation).
- Nom public de l'appli.
