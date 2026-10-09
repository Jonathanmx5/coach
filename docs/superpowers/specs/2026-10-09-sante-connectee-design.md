# Coach : santé connectée (Health Connect)

> Complète et remplace la section 6 (« Suivi ») de `2026-10-09-coach-design.md`. Ce chantier est avancé avant l'étape 2, à la demande de l'utilisateur.
> Date : 2026-10-09. Statut : validé en conversation.

## 1. Intention

Coach demande dès le questionnaire si l'utilisateur a une montre ou un bracelet connecté, puis récupère via Health Connect le plus de mesures possible, sommeil compris.

Usages retenus :
- **A. Afficher** : carte « Ma journée » sur l'accueil et écran « Mes données » avec courbes.
- **B. Ajuster les repères alimentaires** avec les calories réellement brûlées.
- **D. Suivre le corps** : poids et masse grasse importés automatiquement.
- (C. Adapter les séances selon le sommeil et la FC : reporté à l'étape 2, avec les programmes.)

Hors périmètre : écriture dans Health Connect, synchronisation en arrière-plan, copie des données santé dans le cloud, GPS, VO2 max (non disponible via l'extension `health` sur Android).

## 2. Technique

- Extension Flutter **`health` 13.3.x** (Health Connect sur Android). `MainActivity` doit hériter de `FlutterFragmentActivity`.
- **Lecture seule**, à l'ouverture de l'appli (accueil) et au « tirer pour rafraîchir ». Pas de tâche de fond.
- **Aucune donnée santé copiée dans Firestore.** Health Connect est la source et garde l'historique. Seul le poids importé met à jour le profil (comme une saisie manuelle).
- Permission **historique** (`READ_HEALTH_DATA_HISTORY`) demandée en plus, sinon la lecture est limitée à 30 jours avant l'autorisation.
- Permission Android `ACTIVITY_RECOGNITION` demandée avec les autres (exigée pour les pas). **Pas de permission de localisation** : la distance des séances n'est pas lue.
- **Politique de confidentialité** : fichier `CONFIDENTIALITE.md` à la racine du dépôt public. Une activité Android `PolitiqueActivity` (cible de l'`activity-alias` `ViewPermissionUsageActivity` et de l'intent `ACTION_SHOW_PERMISSIONS_RATIONALE`) ouvre son URL GitHub dans le navigateur puis se ferme.

### Données lues et usage

| Type `health` | Usage |
|---|---|
| `STEPS`, `DISTANCE_DELTA`, `FLIGHTS_CLIMBED` | Ma journée |
| `ACTIVE_ENERGY_BURNED`, `TOTAL_CALORIES_BURNED` | Ma journée + ajustement des repères (B) |
| `SLEEP_SESSION`, `SLEEP_DEEP`, `SLEEP_LIGHT`, `SLEEP_REM`, `SLEEP_AWAKE`, `SLEEP_ASLEEP` | Ma journée (durée et phases) |
| `HEART_RATE`, `RESTING_HEART_RATE`, `HEART_RATE_VARIABILITY_RMSSD` | Indicateurs santé |
| `BLOOD_OXYGEN`, `RESPIRATORY_RATE` | Indicateurs santé (si mesurés) |
| `WORKOUT` | Activités de la journée (type, durée, calories) |
| `WEIGHT`, `BODY_FAT_PERCENTAGE` | Profil mis à jour (D) + courbes |

## 3. Questionnaire

Deux nouvelles étapes après « santé », et avant « connexion » le cas échéant :

1. **`montre`** : « As-tu une montre ou un bracelet connecté ? » (Oui / Non).
2. **`appMontre`** (seulement si oui) : « Quelle application l'accompagne ? » parmi Google Fit, Samsung Health, Mi Fitness, Fitbit, Garmin Connect, Autre. Un encadré explique d'activer le partage de cette application vers Health Connect. Le bouton « Autoriser l'accès » demande les permissions Health Connect (+ historique + reconnaissance d'activité).
   - Health Connect absent : bouton « Installer Health Connect ».
   - Refus ou annulation : message bienveillant ; « Suivant » reste possible (l'appli marche avec les estimations).

Le nombre total d'étapes devient variable (« Étape X sur N » suit la liste réelle). Le profil gagne `montre` (bool, défaut `false` pour les anciens profils), `appMontre` (nullable) et `poidsDate` (date de la pesée connue, nullable).

## 4. Calculs (Dart pur, testés)

- **Agrégation par jour** (fuseau du téléphone) : pas, distance, étages, calories actives et totales = sommes ; FC moyenne = moyenne des mesures ; FC au repos, variabilité, SpO2, fréquence respiratoire = dernière valeur du jour.
- **Sommeil** : une nuit est rattachée au **jour où elle se termine**. Résumé = durée totale endormi (léger + profond + paradoxal, ou `SLEEP_ASLEEP` si pas de phases), durée de chaque phase, durée d'éveil. Les segments qui se chevauchent ne sont comptés qu'une fois.
- **Maintien mesuré (B)** : sur les 7 jours précédant aujourd'hui (aujourd'hui exclu, journée incomplète), s'il y a **au moins 4 jours** avec des calories totales > 0, le maintien = moyenne de ces jours. Sinon, le maintien estimé (Mifflin-St Jeor × type de vie) est conservé. Les ajustements d'objectif (−15 % plafonné à −500 kcal, +10 %) et les planchers (1 200 / 1 500 kcal) s'appliquent dans les deux cas. `Reperes` indique la source (`estime` ou `mesure`).
- **Poids (D)** : la pesée Health Connect la plus récente remplace le poids du profil si elle est plus récente que `poidsDate` (ou si `poidsDate` est vide). Les repères sont recalculés et le profil est enregistré.

## 5. Écrans

- **Accueil** : la tuile calories affiche « Mesuré par ta montre » ou « Estimé ». Sous les repères, une carte **« Ma journée »** (pas, calories brûlées, sommeil de la nuit, FC au repos), avec un appui qui ouvre « Mes données ». Sans montre, la carte invite à en connecter une (lien vers « Modifier mon profil »).
- **Mes données** : sections Activité, Sommeil, Cœur, Corps. Chaque section donne la valeur du jour et une courbe sur **7 jours**, avec un bouton pour passer à **30 jours**. Une mesure absente sur toute la période n'est pas affichée.
- Les textes restent dans l'ARB français.

## 6. Erreurs

| Situation | Comportement |
|---|---|
| Health Connect absent | Bouton d'installation ; appli utilisable avec les estimations |
| Permissions refusées | Message bienveillant ; carte « Ma journée » propose de réessayer |
| Lecture en échec | Les données affichées restent les dernières lues ; message discret |
| Peu de données (< 4 jours) | Repères « Estimé » |

## 7. Tests

- Agrégation, résumé du sommeil (chevauchements, nuit à cheval sur minuit), maintien mesuré (seuil de 4 jours, aujourd'hui exclu), choix du poids : tests unitaires avec des points synthétiques.
- Questionnaire : étapes conditionnelles, total variable, profils anciens sans `montre`.
- Écrans : faux `SanteService` (jours, poids, refus, absence).
- Vérification réelle sur le téléphone de l'utilisateur avec sa montre.
