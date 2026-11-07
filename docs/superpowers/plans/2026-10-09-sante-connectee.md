# Santé connectée : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** l'appli demande si l'utilisateur a une montre, lit Health Connect (activité, sommeil, cœur, corps), affiche « Ma journée » et « Mes données », ajuste les repères avec les calories mesurées et importe le poids.

**Architecture :** la logique (agrégation par jour, sommeil, maintien mesuré, choix du poids) est en Dart pur sur des `PointSante` neutres. `SanteService` (interface) isole l'extension `health`. Un faux service sert aux tests d'écrans. Rien n'est copié dans le cloud, sauf le poids du profil.

**Tech Stack :** Flutter 3.47.6, `health` ^13.3.2, `fl_chart` (courbes), Kotlin pour `PolitiqueActivity`.

**Spec :** `docs/superpowers/specs/2026-10-09-sante-connectee-design.md`, qui complète `2026-10-09-coach-design.md`.

## Global Constraints

- Les mêmes que le plan de l'étape 1 : Flutter via `/c/src/flutter/bin/flutter`, textes uniquement dans `lib/l10n/app_fr.arb` (puis `flutter gen-l10n`), code nommé en français, commits avec `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Lecture seule. Aucune donnée santé dans Firestore (sauf poids et `poidsDate` du profil).
- Seuil du maintien mesuré : ≥ 4 jours sur les 7 précédents, aujourd'hui exclu. Une nuit de sommeil est rattachée au jour de sa fin.
- Anciens profils Firestore sans `montre` → `montre: false`, `appMontre: null`, `poidsDate: null`.
- Pas de permission de localisation.

## Review Focus

1. **Nuit à cheval sur minuit** (coucher 23 h, lever 7 h) : rattachée au jour du lever, comptée une seule fois. Test dans la tâche 2.
2. **Segments de sommeil qui se chevauchent** (deux sources, montre + téléphone) : ne pas doubler la durée. Test dans la tâche 2.
3. **Journée en cours** (calories partielles du jour) : exclue de la moyenne du maintien. Test dans la tâche 3.
4. **Ancien profil sans champs montre** lu depuis Firestore : ne plante pas. Test dans la tâche 4.
5. **Health Connect absent ou refusé** : l'accueil s'affiche normalement, avec les repères « Estimé ». Test dans la tâche 7.

---

### Task 1: Configuration Android et politique de confidentialité

**Files :** `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/main/kotlin/io/github/jonathanmx5/coach/MainActivity.kt`, Create `.../PolitiqueActivity.kt`, Create `CONFIDENTIALITE.md` (racine du dépôt).

- [ ] Manifest : `uses-permission` `android.permission.health.READ_*` pour STEPS, DISTANCE, FLOORS_CLIMBED, ACTIVE_CALORIES_BURNED, TOTAL_CALORIES_BURNED, SLEEP, HEART_RATE, RESTING_HEART_RATE, HEART_RATE_VARIABILITY, OXYGEN_SATURATION, RESPIRATORY_RATE, EXERCISE, WEIGHT, BODY_FAT, plus `READ_HEALTH_DATA_HISTORY` et `android.permission.ACTIVITY_RECOGNITION`. `<queries>` sur le paquet `com.google.android.apps.healthdata` et l'action `ACTION_SHOW_PERMISSIONS_RATIONALE`. `PolitiqueActivity` (exportée) avec un intent-filter `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE`, et un `activity-alias` `ViewPermissionUsageActivity` vers elle (`VIEW_PERMISSION_USAGE` + `HEALTH_PERMISSIONS`).
- [ ] `MainActivity : FlutterFragmentActivity()`. `PolitiqueActivity` ouvre `https://github.com/Jonathanmx5/coach/blob/main/CONFIDENTIALITE.md` (ACTION_VIEW) puis appelle `finish()`.
- [ ] `CONFIDENTIALITE.md` : données lues (liste de la spec §2), usage, stockage local uniquement (sauf profil et poids dans Firestore Europe), aucune revente ni partage, suppression du compte, contact (adresse du compte GitHub).
- [ ] Vérification : `flutter build apk --debug` réussit, et `build/app/intermediates/merged_manifests/debug/**/AndroidManifest.xml` contient `READ_SLEEP` et `PolitiqueActivity`. `flutter test` reste au vert.
- [ ] Commit « Health Connect : permissions Android et politique de confidentialité ».

### Task 2: Modèle santé, agrégation par jour, sommeil

**Files :** Create `app/lib/sante/modele.dart`, `app/lib/sante/agregation.dart`. Test `app/test/sante/agregation_test.dart`.

**Produces :**
- `enum TypeMesure { pas, distance, etages, kcalActives, kcalTotales, fc, fcRepos, variabilite, spo2, freqResp, poids, masseGrasse, sommeilProfond, sommeilLeger, sommeilParadoxal, sommeilEveil, sommeilEndormi, seance }`
- `class PointSante { TypeMesure type; DateTime debut; DateTime fin; double valeur; String? libelle; }` (`libelle` = type de séance)
- `class ResumeSommeil { Duration endormi, profond, leger, paradoxal, eveil; }`
- `class Seance { String type; DateTime debut; Duration duree; double? kcal; }`
- `class JourSante { DateTime jour; int? pas; double? distanceM; int? etages; double? kcalActives; double? kcalTotales; double? fcMoyenne; double? fcRepos; double? variabiliteMs; double? spo2; double? freqResp; ResumeSommeil? sommeil; List<Seance> seances; }`
- `class Mesure { DateTime date; double valeur; }`
- `List<JourSante> agregerParJour(List<PointSante> points, {required DateTime debut, required DateTime fin})` : un `JourSante` par jour calendaire local de `debut` à `fin` inclus. Les jours sans donnée ont tous leurs champs `null` et `seances` vide.
- `ResumeSommeil? resumerSommeil(List<PointSante> segments)` : fusionne les intervalles qui se chevauchent par type (par phase). `endormi` = profond + léger + paradoxal si des phases existent, sinon durée fusionnée de `sommeilEndormi`.
- `List<Mesure> mesures(List<PointSante> points, TypeMesure type)` : triées par date.

- [ ] Tests (RED puis GREEN) :
  - pas de 3 points le même jour → somme ;
  - FC moyenne → moyenne ; FC au repos → dernière valeur du jour ;
  - **nuit de 23 h à 7 h** (profond 23 h-1 h, léger 1 h-5 h, paradoxal 5 h-7 h) → rattachée au jour du lever, `endormi` = 8 h, `profond` = 2 h ;
  - **deux segments `sommeilLeger` qui se chevauchent** (1 h-3 h et 2 h-4 h) → `leger` = 3 h ;
  - seulement `sommeilEndormi` (sans phases) → `endormi` = sa durée ;
  - jour sans données → champs nuls ;
  - séance → dans `seances` du jour de début.
- [ ] Commit « Santé : agrégation par jour et résumé du sommeil ».

### Task 3: Maintien mesuré et choix du poids

**Files :** Modify `app/lib/profil/besoins.dart`, Create `app/lib/sante/ajustements.dart`. Tests `app/test/sante/ajustements_test.dart` et `app/test/profil/besoins_test.dart`.

**Produces :**
- `enum SourceMaintien { estime, mesure }`. `Reperes` gagne `final SourceMaintien source` (défaut `estime`, inclus dans `toMap`/`fromMap`, absent → `estime`).
- `calculerReperes(Profil p, {required DateTime maintenant, double? maintienMesure})` : si `maintienMesure` est fourni, il remplace `base × facteur` et `source = mesure`. Le reste est inchangé.
- `double? maintienMesure(List<JourSante> jours, {required DateTime aujourdhui})` : jours strictement avant `aujourdhui` et au plus 7 jours avant, `kcalTotales > 0` ; renvoie la moyenne s'il y en a au moins 4, sinon `null`.
- `Mesure? poidsAImporter(List<Mesure> pesees, DateTime? poidsDate)` : la plus récente si elle est postérieure à `poidsDate` (ou `poidsDate` null), sinon `null`.

- [ ] Tests :
  - 4 jours à 2 500 et 2 700 → 2 600 ;
  - 3 jours → `null` ;
  - **aujourd'hui (500 kcal partiels) ignoré** ;
  - un jour à 8 jours d'écart ignoré ;
  - profil « perte simple » + maintien mesuré 3 000 → `kcalCible` 2 550 (3000 × 0,85) et `source == mesure` ;
  - pesée plus ancienne que `poidsDate` → `null`.
  - Les 6 tests existants de `besoins_test` restent verts (`source == estime`).
- [ ] Commit « Repères : maintien mesuré par la montre et import du poids ».

### Task 4: Profil : montre, application, date du poids

**Files :** Modify `app/lib/profil/modele.dart`. Test `app/test/profil/modele_test.dart`.

**Produces :** `enum AppMontre { googleFit, samsungHealth, miFitness, fitbit, garmin, autre }` ; `Profil` gagne `bool montre` (requis), `AppMontre? appMontre`, `DateTime? poidsDate` (stocké en millisecondes epoch). `copyWith` gère ces champs, y compris les remises à `null` via des paramètres `bool effacerAppMontre`.

- [ ] Tests : aller-retour avec `montre: true, appMontre: miFitness, poidsDate: 2026-10-01` ; **map sans ces clés → `montre false`, `appMontre null`, `poidsDate null`**.
- [ ] Mettre à jour les profils construits dans les tests existants (`montre: false`).
- [ ] Commit « Profil : montre connectée et date de pesée ».

### Task 5: Service santé, questionnaire et autorisations

**Files :** Create `app/lib/sante/sante_service.dart` (interface + `HealthSanteService`). Modify `controleur.dart`, `etapes.dart`, `questionnaire_page.dart`, `racine.dart`, `accueil_page.dart`, `main.dart`, ARB. Tests : `controleur_test.dart`, `questionnaire_page_test.dart`, `test/fakes.dart` (`FauxSante`).

**Produces :**
- `enum DispoSante { disponible, aInstaller, indisponible }`
- `abstract class SanteService { Future<DispoSante> disponibilite(); Future<void> installer(); Future<bool> demanderAutorisations(); Future<List<PointSante>> lire(DateTime debut, DateTime fin); }`
- `HealthSanteService` : `Health().configure()` ; `getHealthConnectSdkStatus` → `DispoSante` ; `demanderAutorisations` = `Permission`-free : `requestAuthorization(types, permissions: READ)`, puis `requestHealthDataHistoryAuthorization()` ; ACTIVITY_RECOGNITION est demandée via `requestAuthorization` (si l'extension ne la demande pas, ajouter `permission_handler`, avec une Ruling dans le ledger). `lire` appelle `getHealthDataFromTypes` puis convertit chaque `HealthDataPoint` en `PointSante` (les phases de sommeil avec `debut`/`fin` et une valeur en minutes, `WORKOUT` → `seance` avec un libellé de type d'activité).
- Contrôleur : `Etape.montre` et `Etape.appMontre` insérées après `sante`. `etapes` devient un getter calculé (`appMontre` seulement si `montre == true` ; `connexion` en dernier si `avecConnexion`). `repondreMontre(bool)`, `choisirAppMontre(AppMontre)`. `peutContinuer` : `montre` exige une réponse, `appMontre` exige un choix.
- `QuestionnairePage` reçoit `SanteService sante`. À l'étape `appMontre`, après le choix : encadré « active le partage vers Health Connect dans {app} », puis bouton « Autoriser l'accès » (ou « Installer Health Connect »). Résultat affiché (accordé / refusé, avec un message bienveillant). « Suivant » n'est pas bloqué par le résultat.

- [ ] Tests contrôleur : `montre` non → `etapes` sans `appMontre` (total 10 avec connexion) ; oui → avec (11) ; profil construit avec `montre`/`appMontre`.
- [ ] Tests page : appMontre → « Autoriser l'accès » → `FauxSante.autorisationsDemandees == 1` et texte d'accord ; refus → message bienveillant et « Suivant » actif ; `aInstaller` → bouton « Installer Health Connect ».
- [ ] Mettre à jour `parcours.dart` (réponse « Non » à la montre) et les compteurs « Étape X sur N ».
- [ ] Commit « Questionnaire : montre connectée et autorisations Health Connect ».

### Task 6: Accueil : Ma journée, repères mesurés, poids importé

**Files :** Create `app/lib/sante/suivi.dart` (`class Suivi extends ChangeNotifier`). Modify `accueil_page.dart`, `racine.dart`, ARB. Test `app/test/racine_test.dart` (+ `test/sante/suivi_test.dart`).

**Produces :** `Suivi({required SanteService sante, required DateTime Function() horloge})` avec `Future<void> charger({required bool montre})` qui lit les 30 derniers jours (rien si `montre` est faux ou si l'accès n'est pas disponible), puis `List<JourSante> jours`, `JourSante? aujourdhui`, `double? maintienMesure`, `List<Mesure> pesees`, `List<Mesure> masseGrasse`, `EtatSuivi etat` (`inactif`, `chargement`, `pret`, `erreur`).
- L'accueil calcule les repères en direct : `calculerReperes(profil, maintenant, maintienMesure: suivi.maintienMesure)`. La tuile calories affiche « Mesuré par ta montre » ou « Estimé ».
- Si `poidsAImporter(...)` renvoie une pesée : le profil est enregistré avec le nouveau poids, `poidsDate` et les repères recalculés (sans attendre la fin de l'écriture).
- Carte « Ma journée » : pas, kcal brûlées, sommeil (h min), FC au repos ; sans montre → « Connecte ta montre » (ouvre « Modifier mon profil »). `RefreshIndicator` relance `charger`.

- [ ] Tests :
  - avec `FauxSante` (8 jours à 2 600 kcal, pas, sommeil) → « Mesuré par ta montre », `kcalCible` affichée selon le maintien mesuré, pas du jour affichés ;
  - **`FauxSante` indisponible ou refusé → accueil normal, « Estimé »** ;
  - pesée plus récente → `FauxDepot` reçoit le nouveau poids.
- [ ] Commit « Accueil : Ma journée, repères mesurés et poids importé ».

### Task 7: Écran « Mes données »

**Files :** Create `app/lib/sante/mes_donnees_page.dart`. Modify `accueil_page.dart` (un appui sur la carte ouvre la page), ARB, `pubspec.yaml` (`fl_chart`). Test `app/test/sante/mes_donnees_page_test.dart`.

- Sections Activité (pas, kcal actives, distance, étages), Sommeil (durée + phases, barres empilées), Cœur (FC au repos, variabilité, SpO2, fréquence respiratoire), Corps (poids, masse grasse). Chaque mesure : valeur du jour et courbe en barres ou en ligne ; bascule 7 j / 30 j.
- Une mesure absente sur toute la période n'est pas affichée.

- [ ] Tests : avec des jours synthétiques → titres de section présents, « 7 jours » / « 30 jours » change le nombre de barres ; aucune donnée de SpO2 → pas de ligne SpO2.
- [ ] Commit « Écran Mes données avec courbes 7 et 30 jours ».

### Task 8: Vérification sur le téléphone

- [ ] Installer, passer le questionnaire avec « Oui » à la montre puis Mi Fitness (ou l'appli de l'utilisateur), autoriser l'accès, vérifier « Ma journée », le sommeil de la nuit, « Mes données » et la source « Mesuré ». Ouvrir la politique depuis l'écran des autorisations Health Connect.
- [ ] Corriger chaque écart avec un test, puis commiter.
