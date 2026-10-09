# Étape 1 : Socle, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** une appli Android installable où un nouvel utilisateur répond au questionnaire, se connecte avec Google, voit son profil et ses repères sauvegardés dans Firestore, et les retrouve en se reconnectant sur un autre téléphone.

**Architecture :** le dépôt `COACH/` contient `app/` (Flutter) et `firebase/` (règles Firestore et leurs tests ; le relais Cloudflare viendra à l'étape 3 dans `relais/`). La logique (profil, besoins, garde-fous, questionnaire) est en Dart pur, testée unitairement. L'interface reçoit ses services (`AuthService`, `ProfilRepository`) par constructeur, ce qui permet de les remplacer par des faux dans les tests de widgets. Pas de gestionnaire d'état externe : `ChangeNotifier` et `StreamBuilder` suffisent.

**Tech Stack :** Flutter 3.47.6 / Dart 3.13.5, firebase_core, firebase_auth, cloud_firestore, firebase_crashlytics, google_sign_in 7.x, flutter_localizations (gen-l10n), fake_cloud_firestore (tests) ; Node 24 + firebase-tools + @firebase/rules-unit-testing + vitest (tests des règles).

**Spec :** `docs/superpowers/specs/2026-10-09-coach-design.md` (sections 1, 2.1, 2.2, 3, 7, 8, 9 pour l'étape 1).

## Global Constraints

- Flutter n'est pas dans le PATH : toutes les commandes utilisent `/c/src/flutter/bin/flutter` (Git Bash), lancées depuis `COACH/app`.
- Android uniquement : `flutter create --platforms android`. `applicationId` = `io.github.jonathanmx5.coach` (définitif, ne jamais changer). `minSdk` = 26 (requis par Health Connect à l'étape 4).
- Langue : français uniquement. **Aucun texte affiché codé en dur** : tout passe par `lib/l10n/app_fr.arb` (gen-l10n).
- Firestore : région `eur3` (Europe). Données uniquement sous `users/{uid}`.
- Aucun secret dans le dépôt. `google-services.json` et `firebase_options.dart` peuvent être commités (non secrets, selon la spec §9).
- Garde-fous de la spec §3, valeurs exactes : âge minimum 18 ; IMC < 18,5 → pas de « perdre du poids » ; problème de santé → pas de « perdre du poids ».
- Plages de saisie : âge 18-100, taille 120-230 cm, poids 30-300 kg ; jours 2-5 ; durée ∈ {20, 30, 45, 60}.
- Nommage du code : en français, comme la spec (`Profil`, `Reperes`, `calculerReperes`…).
- Commits avec l'identité locale déjà configurée (Jonathanmx5) et la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Saisie décimale française** (« 72,5 » pour le poids) : doit être acceptée comme 72,5. Test dans la tâche 2.
2. **Utilisateur existant sur un nouveau téléphone** (« J'ai déjà un compte » avec un profil existant) : il arrive directement à l'accueil, sans refaire le questionnaire. Test dans la tâche 9.
3. **Enregistrement hors-ligne** : avec Firestore hors-ligne, `set()` ne se termine qu'à la synchronisation. L'appli ne doit jamais attendre cette fin pour avancer. Test dans la tâche 9 (faux dépôt dont `enregistrer` ne se termine jamais : l'accueil s'affiche quand même).
4. **Annulation de la fenêtre Google** : l'utilisateur reste sur l'étape de connexion, sans message d'erreur et avec ses réponses intactes. Test dans la tâche 8.
5. **Contournement d'un garde-fou en revenant en arrière** (santé = oui, puis retour à l'objectif pour choisir « perdre du poids ») : le profil final doit quand même être en « garder la forme ». Les garde-fous sont réappliqués à la construction du profil. Test dans la tâche 7.

---

### Task 1: Projet Flutter, localisation et thème

**Files :**
- Create : `app/` (via `flutter create`), `app/l10n.yaml`, `app/lib/l10n/app_fr.arb`, `app/lib/app.dart`, `app/lib/main.dart` (remplacé)
- Modify : `app/pubspec.yaml`, `app/android/app/build.gradle.kts` (minSdk)
- Create : `COACH/.gitignore`, `COACH/README.md` (3 lignes : but, structure des dossiers, renvoi vers la spec)
- Test : `app/test/app_test.dart`

**Interfaces :**
- Produces : `class CoachApp extends StatelessWidget { const CoachApp({super.key, required Widget accueil}); }`. Il fournit le `MaterialApp` (thème, `locale: Locale('fr')`, délégués de localisation), avec `accueil` comme `home`. `AppLocalizations.of(context)` est disponible dans toute l'appli via `package:coach/l10n/app_localizations.dart`.

- [ ] **Étape 1 : créer le projet**

Run (dans `COACH/`) : `/c/src/flutter/bin/flutter create --org io.github.jonathanmx5 --project-name coach --platforms android app`
Expected : « All done! ». Ensuite, `applicationId` vaut `io.github.jonathanmx5.coach` dans `app/android/app/build.gradle.kts`. Y fixer `minSdk = 26`.

- [ ] **Étape 2 : localisation.** Ajouter `flutter_localizations` (sdk) et `intl` (`flutter pub add flutter_localizations --sdk=flutter` puis `flutter pub add intl`), et `generate: true` dans la section `flutter:`. Créer `l10n.yaml` : `arb-dir: lib/l10n`, `template-arb-file: app_fr.arb`, `output-localization-file: app_localizations.dart`, `output-dir: lib/l10n`. Créer `app_fr.arb` avec **toutes** les chaînes de l'étape (texte exact) :

```json
{
  "@@locale": "fr",
  "appTitre": "Coach",
  "bienvenueTitre": "Ton coach sport et alimentation",
  "bienvenueSousTitre": "Un programme adapté à toi, en une minute.",
  "boutonCommencer": "Commencer",
  "boutonDejaCompte": "J'ai déjà un compte",
  "boutonSuivant": "Suivant",
  "boutonRetour": "Retour",
  "boutonOui": "Oui",
  "boutonNon": "Non",
  "qObjectif": "Quel est ton objectif ?",
  "objectifPerte": "Perdre du poids",
  "objectifMuscle": "Prendre du muscle",
  "objectifForme": "Garder la forme",
  "objectifReprise": "Reprendre le sport",
  "qSexeAge": "Parle-nous un peu de toi",
  "sexeHomme": "Homme",
  "sexeFemme": "Femme",
  "sexeExplication": "Sert uniquement au calcul de tes besoins.",
  "champAge": "Âge",
  "qMensurations": "Ta taille et ton poids",
  "champTaille": "Taille (cm)",
  "champPoids": "Poids (kg)",
  "qTypeDeVie": "Ton quotidien ressemble plutôt à…",
  "vieSedentaire": "Assis toute la journée",
  "vieSedentaireEx": "Bureau, voiture, peu de marche",
  "viePeuActif": "Un peu actif",
  "viePeuActifEx": "Souvent debout, un peu de marche",
  "vieActif": "Actif",
  "vieActifEx": "Métier physique, beaucoup de marche",
  "vieTresActif": "Très actif",
  "vieTresActifEx": "Travail très physique ou sport tous les jours",
  "qEntrainements": "Où veux-tu t'entraîner ?",
  "qEntrainementsAide": "Plusieurs choix possibles.",
  "entrainementSalle": "Salle de sport",
  "entrainementMaison": "À la maison",
  "entrainementCourse": "Course à pied",
  "entrainementMarche": "Marche",
  "qNiveau": "Ton niveau",
  "niveauDebutant": "Débutant",
  "niveauReprise": "Je reprends",
  "niveauRegulier": "Régulier",
  "qDisponibilite": "Ton temps disponible",
  "champJours": "Jours par semaine",
  "champDuree": "Durée d'une séance",
  "dureeMinutes": "{n} min",
  "@dureeMinutes": {"placeholders": {"n": {"type": "int"}}},
  "qSante": "Es-tu enceinte ou as-tu un problème de santé particulier ?",
  "conseilMedecin": "Parles-en à ton médecin avant de commencer. Par prudence, l'objectif « perdre du poids » est désactivé.",
  "messageMineur": "Coach est réservé aux personnes de 18 ans et plus. Les besoins des adolescents sont différents : parles-en à ton médecin.",
  "messagePerteImc": "Ton poids est déjà bas pour ta taille : on part plutôt sur « garder la forme ».",
  "erreurNombre": "Entre un nombre valide.",
  "erreurPlage": "Entre une valeur entre {min} et {max}.",
  "@erreurPlage": {"placeholders": {"min": {"type": "int"}, "max": {"type": "int"}}},
  "qConnexion": "Dernière étape : sauvegarde ton profil",
  "boutonGoogle": "Continuer avec Google",
  "erreurConnexion": "La connexion a échoué. Vérifie ta connexion internet et réessaie.",
  "mentionMedicale": "Coach ne remplace pas un avis médical.",
  "accueilBonjour": "Bonjour {prenom} !",
  "@accueilBonjour": {"placeholders": {"prenom": {"type": "String"}}},
  "accueilBonjourSansNom": "Bonjour !",
  "accueilProgrammeBientot": "Ton programme arrive bientôt.",
  "boutonVoirReperes": "Voir mes repères",
  "reperesKcal": "{kcal} kcal par jour (estimation)",
  "@reperesKcal": {"placeholders": {"kcal": {"type": "int"}}},
  "reperesProteines": "{g} g de protéines par jour",
  "@reperesProteines": {"placeholders": {"g": {"type": "int"}}},
  "boutonModifierProfil": "Modifier mon profil",
  "boutonDeconnexion": "Se déconnecter"
}
```

- [ ] **Étape 3 : écrire le test qui échoue**, dans `test/app_test.dart` : `testWidgets('CoachApp fournit les textes français', …)`. Il construit `CoachApp(accueil: Builder(builder: (c) => Text(AppLocalizations.of(c)!.boutonCommencer)))` et vérifie `find.text('Commencer')` → `findsOneWidget`.

- [ ] **Étape 4 :** `/c/src/flutter/bin/flutter test test/app_test.dart` → échec (`CoachApp` absent).

- [ ] **Étape 5 : implémenter `CoachApp`** dans `lib/app.dart`. Thème Material 3 avec `ColorScheme.fromSeed(seedColor: Color(0xFF2E7D5B))`, boutons hauts d'au moins 56 px (cible débutant, gros boutons). `main.dart` temporaire : `runApp(CoachApp(accueil: Placeholder()))`. Supprimer le `widget_test.dart` généré.

- [ ] **Étape 6 :** `flutter test` → PASS ; `flutter analyze` → « No issues found! ».

- [ ] **Étape 7 : commit.** Ajouter un `.gitignore` racine (`node_modules/`, `.firebase/`, `*.jks`, `key.properties`), puis `git add -A && git commit -m "Projet Flutter Coach : localisation française et thème"`.

---

### Task 2: Modèle du profil et saisie des nombres

**Files :**
- Create : `app/lib/profil/modele.dart`, `app/lib/profil/saisie.dart`
- Test : `app/test/profil/modele_test.dart`, `app/test/profil/saisie_test.dart`

**Interfaces :**
- Produces :
  - `enum Objectif { perte, muscle, forme, reprise }`, `enum Sexe { homme, femme }`, `enum TypeDeVie { sedentaire, peuActif, actif, tresActif }`, `enum TypeEntrainement { salle, maison, course, marche }`, `enum Niveau { debutant, reprise, regulier }`
  - `class Profil` (immuable, `==`/`hashCode` par valeur), avec les champs `Objectif objectif, Sexe sexe, int anneeNaissance, int tailleCm, double poidsKg, TypeDeVie typeDeVie, Set<TypeEntrainement> typesEntrainement, Niveau niveau, int joursParSemaine, int dureeSeanceMin, bool problemeSante`. Méthodes : `int age(DateTime maintenant)` (= `maintenant.year - anneeNaissance`), `Profil copyWith({...})`, `Map<String, Object?> toMap()` (enums par `.name`, set → liste triée par index), `static Profil fromMap(Map<String, Object?> m)`.
  - `double? lireNombre(String saisie)` : enlève les espaces, remplace `,` par `.`, renvoie `null` si ce n'est pas un nombre fini.

- [ ] **Étape 1 : écrire les tests qui échouent.**
  - `saisie_test.dart` : `lireNombre('72,5') == 72.5`, `lireNombre(' 180 ') == 180`, `lireNombre('72.5') == 72.5`, `lireNombre('') == null`, `lireNombre('abc') == null`, `lireNombre('1,2,3') == null`.
  - `modele_test.dart` : l'aller-retour `Profil.fromMap(p.toMap()) == p` pour un profil avec `{salle, course}` ; `p.toMap()['typesEntrainement'] == ['salle', 'course']` ; `p.toMap()['objectif'] == 'perte'` ; `age(DateTime(2026, 10, 9))` pour `anneeNaissance: 1996` vaut 30.
- [ ] **Étape 2 :** `flutter test test/profil` → échec (symboles absents).
- [ ] **Étape 3 : implémenter** `modele.dart` et `saisie.dart` selon les signatures ci-dessus. `fromMap` lit `poidsKg` comme `num` (Firestore peut renvoyer un `int`).
- [ ] **Étape 4 :** `flutter test test/profil` → PASS.
- [ ] **Étape 5 : commit** `"Modèle du profil et saisie des nombres à la française"`.

---

### Task 3: Calcul des besoins

**Files :**
- Create : `app/lib/profil/besoins.dart`
- Test : `app/test/profil/besoins_test.dart`

**Interfaces :**
- Consumes : `Profil`, ses enums (tâche 2).
- Produces : `class Reperes { final int depenseBase, maintien, kcalCible, proteinesG; Map<String, Object?> toMap(); static Reperes fromMap(Map<String, Object?>); }` (égalité par valeur) et `Reperes calculerReperes(Profil p, {required DateTime maintenant})`.

**Règles (spec §3, valeurs exactes) :**
- Dépense de base : `10·kg + 6,25·cm − 5·âge + 5` (homme), `− 161` (femme). `depenseBase` = arrondi entier (`.round()`).
- Facteurs : sedentaire 1,2 ; peuActif 1,375 ; actif 1,55 ; tresActif 1,725. `maintien` = arrondi entier de `base × facteur` (calcul en `double` non arrondi).
- Cible : perte = `maintien − min(0,15 × maintien, 500)` ; muscle = `× 1,10` ; forme et reprise = maintien. Puis `max(cible, plancher)`, avec un plancher de 1 200 (femme) ou 1 500 (homme). `kcalCible` = arrondi à la dizaine (`(x / 10).round() * 10`). Tous ces calculs partent du maintien non arrondi.
- Protéines : 1,6 g/kg (perte, muscle), 1,2 g/kg (forme, reprise), arrondies à l'entier.

- [ ] **Étape 1 : écrire les tests qui échouent**, avec `maintenant = DateTime(2026, 10, 9)` et l'âge donné via `anneeNaissance = 2026 − âge` :

| Cas | Profil | Attendu `(depenseBase, maintien, kcalCible, proteinesG)` |
|---|---|---|
| perte simple | H, 30 ans, 180 cm, 80 kg, peuActif, perte | (1780, 2448, 2080, 128) |
| déficit plafonné | H, 30 ans, 180 cm, 121 kg, tresActif, perte | (2190, 3778, 3280, 194) |
| plancher femme | F, 60 ans, 150 cm, 45 kg, sedentaire, perte | (927, 1112, 1200, 72) |
| prise de muscle | F, 25 ans, 165 cm, 60 kg, actif, muscle | (1345, 2085, 2290, 96) |
| plancher homme, forme | H, 80 ans, 160 cm, 50 kg, sedentaire, forme | (1105, 1326, 1500, 60) |

Plus l'aller-retour `Reperes.fromMap(r.toMap()) == r`.

- [ ] **Étape 2 :** `flutter test test/profil/besoins_test.dart` → échec.
- [ ] **Étape 3 : implémenter** `calculerReperes` et `Reperes`.
- [ ] **Étape 4 :** → PASS (les 6 tests).
- [ ] **Étape 5 : commit** `"Calcul des besoins (Mifflin-St Jeor, planchers, protéines)"`.

---

### Task 4: Garde-fous

**Files :**
- Create : `app/lib/profil/garde_fous.dart`
- Test : `app/test/profil/garde_fous_test.dart`

**Interfaces :**
- Produces :
  - `double imc(double poidsKg, int tailleCm)`
  - `bool estMineur(int age)` (`age < 18`)
  - `bool pertePermise({required double poidsKg, required int tailleCm, required bool problemeSante})` (vrai si IMC ≥ 18,5 et aucun problème de santé)
  - `Profil appliquerGardeFous(Profil p)` : renvoie `p.copyWith(objectif: Objectif.forme)` si `p.objectif == perte` et que la perte n'est pas permise, sinon `p` inchangé.

- [ ] **Étape 1 : écrire les tests qui échouent.** `estMineur(17)` vrai, `estMineur(18)` faux. `pertePermise(53.4, 170, false)` faux (IMC 18,48) ; `pertePermise(53.5, 170, false)` vrai ; `pertePermise(80, 180, true)` faux. `appliquerGardeFous` : perte + santé → forme ; perte + IMC bas → forme ; muscle + santé → reste muscle ; perte + profil normal → reste perte.
- [ ] **Étape 2 :** → échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 :** → PASS.
- [ ] **Étape 5 : commit** `"Garde-fous : âge minimum, IMC bas, problème de santé"`.

---

### Task 5: Firebase (projet, configuration, initialisation, Crashlytics)

Tâche en partie **manuelle par l'utilisateur** : connexion à son compte Google et actions dans la console Firebase. L'agent prépare, guide, puis vérifie.

**Files :**
- Create (générés) : `app/lib/firebase_options.dart`, `app/android/app/google-services.json`
- Modify : `app/lib/main.dart`, fichiers Gradle (modifiés par `flutterfire configure`)

**Interfaces :**
- Produces : `Future<void> main()` qui initialise Firebase (`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`), active la persistance Firestore (`Settings(persistenceEnabled: true)`), branche Crashlytics (`FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`, `PlatformDispatcher.instance.onError` → `recordError(..., fatal: true)`, collecte désactivée si `kDebugMode`).

- [ ] **Étape 1 (agent) : installer les outils.** `npm install -g firebase-tools` puis `/c/src/flutter/bin/dart pub global activate flutterfire_cli`. Expected : `firebase --version` et `flutterfire --version` répondent.
- [ ] **Étape 2 (utilisateur) :** dans un terminal, lancer `firebase login`.
- [ ] **Étape 3 (utilisateur, console Firebase) :**
  - créer le projet « coach » sans Google Analytics ;
  - **Authentication** → activer le fournisseur Google ;
  - **Firestore** → créer la base en mode production, emplacement `eur3` ;
  - **Crashlytics** → activer.
- [ ] **Étape 4 (agent) :** `flutter pub add firebase_core firebase_auth cloud_firestore firebase_crashlytics`, puis, depuis `app/`, `flutterfire configure --project=<id du projet> --platforms=android --android-package-name=io.github.jonathanmx5.coach`. Expected : `lib/firebase_options.dart` et `android/app/google-services.json` sont créés.
- [ ] **Étape 5 (agent + utilisateur) : empreinte SHA-1.** `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` → l'utilisateur colle la SHA-1 dans les paramètres de l'appli Android de la console Firebase. L'agent relance ensuite `flutterfire configure` pour récupérer un `google-services.json` à jour, qui doit contenir un `oauth_client` avec `client_type: 3`.
- [ ] **Étape 6 (agent) : écrire `main.dart`** selon l'interface, avec `runApp(CoachApp(accueil: Placeholder()))` pour l'instant.
- [ ] **Étape 7 (agent) :** `flutter build apk --debug`. Expected : « Built build\app\outputs\flutter-apk\app-debug.apk ». `flutter test` → toujours PASS.
- [ ] **Étape 8 : commit** `"Configuration Firebase, persistance hors-ligne et Crashlytics"`.

---

### Task 6: Règles Firestore et leurs tests

**Files :**
- Create : `firebase/firebase.json`, `firebase/.firebaserc` (projet par défaut = id réel), `firebase/firestore.rules`, `firebase/package.json`, `firebase/test/regles.test.js`

**Interfaces :**
- Produces : des règles où `users/{uid}` et `users/{uid}/{document=**}` sont lisibles et modifiables uniquement si `request.auth.uid == uid`. Tout le reste est refusé.

- [ ] **Étape 1 : préparer.** `package.json` (type module), avec en devDependencies `firebase-tools`, `@firebase/rules-unit-testing`, `firebase` et `vitest`. Script `"test": "firebase emulators:exec --only firestore --project demo-coach \"vitest run\""`. `firebase.json` déclare `firestore.rules` et l'émulateur Firestore. Commencer avec des règles qui refusent tout (`allow read, write: if false;`).
- [ ] **Étape 2 : écrire les tests** (`initializeTestEnvironment` avec `projectId: 'demo-coach'` et les règles lues depuis le fichier) :
  - `alice` lit et écrit `users/alice` → succès (`assertSucceeds`) ;
  - `alice` lit et écrit `users/alice/meals/m1` → succès ;
  - `alice` lit `users/bob` → échec (`assertFails`) ;
  - `alice` écrit `users/bob/meals/m1` → échec ;
  - un non-connecté lit `users/alice` → échec ;
  - `alice` écrit `autre/x` → échec.
- [ ] **Étape 3 :** `cd firebase && npm install && npm test` → les tests d'accès autorisé échouent.
- [ ] **Étape 4 : écrire les vraies règles.**
- [ ] **Étape 5 :** `npm test` → 6 PASS.
- [ ] **Étape 6 : déployer.** `npx firebase deploy --only firestore:rules`. Expected : « Deploy complete! ».
- [ ] **Étape 7 : commit** `"Règles Firestore : chaque utilisateur n'accède qu'à ses données"`.

---

### Task 7: Contrôleur du questionnaire (logique pure)

**Files :**
- Create : `app/lib/profil/questionnaire/controleur.dart`
- Test : `app/test/profil/questionnaire/controleur_test.dart`

**Interfaces :**
- Consumes : `Profil` et ses enums, `lireNombre` (tâche 2), `estMineur`, `pertePermise`, `appliquerGardeFous` (tâche 4).
- Produces :
  - `enum Etape { objectif, sexeAge, mensurations, typeDeVie, entrainements, niveau, disponibilite, sante, connexion }`
  - `enum Alerte { mineur, perteRefuseeImc, conseilMedecin }`
  - `enum ErreurChamp { nombreInvalide, horsPlage }`
  - `class QuestionnaireControleur extends ChangeNotifier` :
    - constructeurs `QuestionnaireControleur({required DateTime maintenant, required bool avecConnexion})` et `QuestionnaireControleur.depuis(Profil p, {required DateTime maintenant})` (prérempli, `avecConnexion: false`) ;
    - getters `Etape etape`, `Alerte? alerte`, `bool peutContinuer`, `double progression` (0 → 1), `List<Etape> etapes` (sans `connexion` si `avecConnexion` est faux) ;
    - saisies `choisirObjectif(Objectif)`, `choisirSexe(Sexe)`, `ErreurChamp? saisirAge(String)`, `ErreurChamp? saisirTaille(String)`, `ErreurChamp? saisirPoids(String)`, `choisirTypeDeVie(TypeDeVie)`, `basculerEntrainement(TypeEntrainement)`, `choisirNiveau(Niveau)`, `choisirJours(int)`, `choisirDuree(int)`, `repondreSante(bool)` ;
    - navigation `suivant()`, `precedent()` ;
    - `Profil construireProfil()` : n'est valide que si toutes les réponses sont présentes, et passe toujours par `appliquerGardeFous`.

**Comportement :**
- `peutContinuer` est vrai seulement quand la réponse de l'étape est valide. Étape `entrainements` : au moins un type. `disponibilite` : un nombre de jours (2-5) et une durée dans {20, 30, 45, 60}.
- Un âge valide mais inférieur à 18 donne `alerte = mineur`, et `peutContinuer` reste faux pour cette étape. Un âge supérieur à 100 donne `horsPlage`.
- En quittant `mensurations` avec l'objectif `perte` et une perte non permise par l'IMC : `objectif` passe à `forme` et `alerte = perteRefuseeImc`.
- `repondreSante(true)` : si l'objectif est `perte`, il passe à `forme`. Dans tous les cas, `alerte = conseilMedecin`.
- `suivant()` et `precedent()` effacent l'alerte (sauf `mineur`, qui reste tant que l'âge n'est pas corrigé).
- `precedent()` conserve toutes les réponses.

- [ ] **Étape 1 : écrire les tests qui échouent :**
  - parcours complet → `construireProfil()` égal au profil attendu, avec `anneeNaissance = 2026 − âge` ;
  - `saisirPoids('72,5')` → aucune erreur, et le poids vaut 72,5 ;
  - `saisirAge('17')` → `alerte == mineur` et `peutContinuer` faux ; `saisirAge('101')` → `horsPlage` ; `saisirTaille('abc')` → `nombreInvalide` ;
  - `entrainements` sans choix → `peutContinuer` faux ; après `basculerEntrainement(salle)` → vrai ; un second basculement le retire ;
  - perte + 170 cm / 50 kg → au `suivant()` depuis `mensurations`, l'objectif devient forme et `alerte == perteRefuseeImc` ;
  - **Review Focus 5 :** santé = oui, puis `precedent()` jusqu'à `objectif`, `choisirObjectif(perte)`, puis retour jusqu'à la fin → `construireProfil().objectif == Objectif.forme` ;
  - `depuis(profil)` → `etapes` sans `connexion`, et toutes les réponses sont préremplies (`construireProfil() == profil`).
- [ ] **Étape 2 :** → échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 :** → PASS.
- [ ] **Étape 5 : commit** `"Contrôleur du questionnaire avec garde-fous"`.

---

### Task 8: Services (connexion, dépôt du profil) et écrans du questionnaire

**Files :**
- Create : `app/lib/compte/auth_service.dart`, `app/lib/profil/profil_repository.dart`, `app/lib/profil/questionnaire/questionnaire_page.dart`, `app/lib/profil/questionnaire/etapes.dart` (un widget par étape)
- Create (tests) : `app/test/fakes.dart`, `app/test/profil/profil_repository_test.dart`, `app/test/profil/questionnaire/questionnaire_page_test.dart`

**Interfaces :**
- Consumes : `QuestionnaireControleur` (tâche 7), `calculerReperes` / `Reperes` (tâche 3).
- Produces :
  - `class Utilisateur { final String uid; final String? prenom; }`
  - `abstract class AuthService { Stream<Utilisateur?> get changements; Utilisateur? get actuel; Future<Utilisateur?> connecterGoogle(); Future<void> deconnecter(); }`. `connecterGoogle` renvoie `null` si l'utilisateur annule et lève `ConnexionEchouee` en cas d'échec.
  - `class FirebaseAuthService implements AuthService`. Il utilise google_sign_in 7.x : `GoogleSignIn.instance.initialize(serverClientId: <client_id du oauth_client client_type 3 de google-services.json, mis en constante>)`, puis `authenticate()`, puis `GoogleAuthProvider.credential(idToken: …)` et `FirebaseAuth.signInWithCredential`. Une `GoogleSignInException` de code `canceled` donne `null`. `prenom` = premier mot de `displayName`.
  - `abstract class ProfilRepository { Stream<ProfilEnregistre?> observer(String uid); Future<void> enregistrer(String uid, Profil p, Reperes r); }`, avec `class ProfilEnregistre { final Profil profil; final Reperes reperes; }`.
  - `class FirestoreProfilRepository implements ProfilRepository`. Le document `users/{uid}` vaut `{profil: p.toMap(), reperes: r.toMap(), schema: 1, majLe: FieldValue.serverTimestamp()}`, écrit avec `set(..., SetOptions(merge: true))`. Un document absent ou sans `profil` donne `null`.
  - `class QuestionnairePage extends StatefulWidget { QuestionnairePage({required QuestionnaireControleur controleur, required AuthService auth, required ProfilRepository depot, required DateTime Function() horloge, required VoidCallback quandTermine}); }`. En fin de parcours (après la connexion si nécessaire), elle appelle `depot.enregistrer(uid, profil, calculerReperes(profil, maintenant: horloge()))` **sans attendre la fin** (`unawaited`), puis `quandTermine()`.
  - Fichier `test/fakes.dart` : `FauxAuth` (connexion programmable : utilisateur, `null` ou exception), `FauxDepot` (stockage en mémoire et option `bloquerEnregistrement` : `enregistrer` renvoie un `Future` qui ne se termine jamais, tout en publiant la donnée dans `observer`).

**Écrans :** un écran par étape, avec la question en titre, de gros boutons de choix (cartes avec le libellé et, pour le type de vie, l'exemple), une barre `LinearProgressIndicator(value: progression)` et les boutons Retour / Suivant (Suivant désactivé si `!peutContinuer`). Les alertes s'affichent dans un encadré bienveillant (pas en rouge), avec les textes ARB correspondants. `mentionMedicale` apparaît en bas de l'étape `sante`. L'étape `connexion` montre le bouton « Continuer avec Google ».

- [ ] **Étape 1 : test du dépôt** (`fake_cloud_firestore` en dev_dependency) : `enregistrer` puis `observer('u1').first` → un `ProfilEnregistre` égal ; un document absent → `null`. Run → échec, implémenter, puis PASS.
- [ ] **Étape 2 : tests de la page qui échouent** (avec `FauxAuth`, `FauxDepot` et une horloge fixe à 2026-10-09) :
  - parcours complet par des tapotements jusqu'à « Continuer avec Google » → `FauxDepot` contient le profil et `quandTermine` a été appelé ;
  - **Review Focus 4 :** connexion annulée (`null`) → toujours sur l'étape connexion, aucun texte `erreurConnexion`, et le profil retrouvé via « Retour » est inchangé ;
  - connexion en erreur → le texte `erreurConnexion` est affiché ;
  - âge 17 → le texte `messageMineur` est affiché et « Suivant » est désactivé ;
  - santé « Oui » → le texte `conseilMedecin` est affiché.
- [ ] **Étape 3 :** → échec.
- [ ] **Étape 4 : implémenter** `auth_service.dart`, `questionnaire_page.dart` et `etapes.dart`.
- [ ] **Étape 5 :** `flutter test` → tout passe ; `flutter analyze` → aucun problème.
- [ ] **Étape 6 : commit** `"Questionnaire : écrans, connexion Google, enregistrement du profil"`.

---

### Task 9: Racine de l'appli et accueil

**Files :**
- Create : `app/lib/racine.dart`, `app/lib/accueil/bienvenue_page.dart`, `app/lib/accueil/accueil_page.dart`
- Modify : `app/lib/main.dart` (`CoachApp(accueil: Racine(auth: FirebaseAuthService(), depot: FirestoreProfilRepository(), horloge: DateTime.now))`)
- Test : `app/test/racine_test.dart`

**Interfaces :**
- Consumes : `AuthService`, `ProfilRepository`, `QuestionnairePage`, `QuestionnaireControleur` (tâche 8), `CoachApp` (tâche 1).
- Produces : `class Racine extends StatelessWidget { Racine({required AuthService auth, required ProfilRepository depot, required DateTime Function() horloge}); }`

**Routage :**
- Non connecté → `BienvenuePage`. « Commencer » pousse `QuestionnairePage` (avec connexion) ; à la fin, retour à la racine. « J'ai déjà un compte » lance `connecterGoogle()` (annulation silencieuse, erreur affichée avec `erreurConnexion`).
- Connecté, profil en cours de chargement → indicateur de chargement.
- Connecté sans profil → `QuestionnairePage` sans étape connexion.
- Connecté avec profil → `AccueilPage`.

**Accueil :** `accueilBonjour(prenom)` (ou `accueilBonjourSansNom`), libellé de l'objectif, carte « Ton programme arrive bientôt. », bouton « Voir mes repères » (affiche `reperesKcal` et `reperesProteines` à partir des repères enregistrés), « Modifier mon profil » (pousse `QuestionnairePage` avec `QuestionnaireControleur.depuis(profil)`), « Se déconnecter », et `mentionMedicale` en pied de page.

- [ ] **Étape 1 : tests qui échouent :**
  - non connecté → les textes « Commencer » et « J'ai déjà un compte » sont présents ;
  - **Review Focus 2 :** `FauxDepot` contient déjà un profil pour `u1`, tap sur « J'ai déjà un compte », `FauxAuth` connecte `u1` → l'accueil (« Bonjour Léa ! ») s'affiche, sans aucun écran du questionnaire ;
  - **Review Focus 3 :** `FauxDepot(bloquerEnregistrement: true)`, parcours complet depuis « Commencer » → l'accueil s'affiche (`pumpAndSettle`) ;
  - « Voir mes repères » → les textes « 2080 kcal par jour (estimation) » et « 128 g de protéines par jour » s'affichent pour le profil « perte simple » de la tâche 3 ;
  - « Se déconnecter » → retour à la page de bienvenue.
- [ ] **Étape 2 :** → échec.
- [ ] **Étape 3 : implémenter.**
- [ ] **Étape 4 :** `flutter test` → tout passe ; `flutter analyze` → aucun problème.
- [ ] **Étape 5 : commit** `"Racine, bienvenue et accueil"`.

---

### Task 10: Vérification sur le téléphone et dépôt GitHub

- [ ] **Étape 1 (utilisateur) :** activer le débogage USB sur le téléphone et le brancher. **Agent :** `adb devices` (depuis `%LOCALAPPDATA%/Android/Sdk/platform-tools`) → le téléphone est listé.
- [ ] **Étape 2 (agent) :** `flutter run -d <id>` (mode debug).
- [ ] **Étape 3 (utilisateur, avec l'agent) : liste de contrôle.**
  1. questionnaire complet, avec un poids saisi « 72,5 » ;
  2. connexion Google ;
  3. affichage de l'accueil et des repères ;
  4. dans la console Firestore, le document `users/{uid}` existe, avec `profil` et `reperes` ;
  5. désinstallation, réinstallation, « J'ai déjà un compte » → l'accueil s'affiche directement ;
  6. en mode avion, « Modifier mon profil » puis enregistrement → l'accueil s'affiche, et la synchronisation se fait au retour du réseau ;
  7. un âge de 17 ans est bloqué.
- [ ] **Étape 4 : corriger** chaque écart constaté avec un test, puis commiter.
- [ ] **Étape 5 (après accord explicite de l'utilisateur) :** créer le dépôt GitHub public et pousser `main` : `gh repo create coach --public --source . --push`. Pas de release à cette étape (APK signé à l'étape 4).
