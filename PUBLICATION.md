# Publier Coach

## Signature (déjà faite sur la machine de développement)

- Clé de publication : `C:\Users\jopit\.coach-signing\coach-release.jks`, avec ses mots de passe dans `key.properties` du même dossier. **À sauvegarder hors de l'ordinateur** (gestionnaire de mots de passe, clé USB) : sans elle, impossible de publier une mise à jour sous la même signature. Elle n'est jamais dans le dépôt.
- `app/android/key.properties` (ignoré par git) pointe vers cette clé ; sans lui, la version « release » est signée avec la clé de débogage.
- Empreinte SHA-1 de la clé : `B7:37:22:E0:69:35:80:2A:D4:8D:2E:88:37:93:86:6E:3F:21:68:04` (publique ; déjà enregistrée dans Firebase pour la connexion Google).

## Compiler

```bash
cd app
flutter build apk --release --split-per-abi    # un APK par processeur (arm64 pour presque tous les téléphones)
flutter build appbundle --release              # .aab pour le Play Store
```

Ajouter `--dart-define=RELAIS_URL=https://…` pour activer la photo de repas.

## Version GitHub

1. Créer le dépôt public, pousser `main`.
2. Créer une release (en brouillon, puis la publier après vérification sur un téléphone) avec l'APK arm64 en pièce jointe et la somme SHA-256 dans les notes.

## Play Store

À faire dans la Play Console (compte développeur payant, une seule fois) :

1. Créer l'application ; choisir le nom définitif (« Coach » est un nom de travail, probablement déjà pris sur le Play Store).
2. Activer **Play App Signing** : Google re-signe l'application avec sa propre clé. **Ajouter alors l'empreinte SHA-1 de la clé de signature d'application** (Console → Intégrité de l'application) dans Firebase (Paramètres du projet → application Android → Ajouter une empreinte), sinon la connexion Google échoue pour les utilisateurs du Play Store.
3. Importer le `.aab`. Premier test en « test interne », puis « test fermé » (les comptes personnels récents doivent faire 12 testeurs pendant 14 jours avant la production).
4. Fiche : description, captures d'écran, icône 512 px, image de présentation.
5. Politique de confidentialité : adresse publique de `CONFIDENTIALITE.md` (par exemple sa page sur GitHub).
6. Formulaire « Sécurité des données » : données collectées = compte Google (identifiant), santé et forme (poids, mensurations, repas, activités, eau, compléments), photos (repas envoyées pour analyse, non conservées), localisation approximative (météo, optionnelle). Chiffrées en transit ; suppression possible sur demande.
7. Déclaration **Health Connect** : l'application lit les données de santé ; la Play Console demande de justifier chaque autorisation (voir la liste dans `AndroidManifest.xml`).
8. Classification du contenu et public cible (adultes uniquement : l'application refuse les moins de 18 ans).

## Avant la première publication

- Restreindre la clé d'API Firebase (Google Cloud Console → Identifiants) à l'application Android `io.github.jonathanmx5.coach` et à sa signature.
- Déployer le relais Cloudflare si la photo de repas doit être disponible (`relais/README.md`).
- Essayer l'APK release sur un téléphone : connexion Google, Health Connect, caméra, notifications.
