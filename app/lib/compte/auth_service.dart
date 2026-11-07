import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Utilisateur {
  const Utilisateur({required this.uid, this.prenom});

  final String uid;
  final String? prenom;
}

/// La connexion a échoué pour une autre raison qu'une annulation.
class ConnexionEchouee implements Exception {
  const ConnexionEchouee(this.cause);

  final Object cause;

  @override
  String toString() => 'ConnexionEchouee($cause)';
}

abstract class AuthService {
  Stream<Utilisateur?> get changements;
  Utilisateur? get actuel;

  /// Renvoie `null` si l'utilisateur annule, lève [ConnexionEchouee] sinon.
  Future<Utilisateur?> connecterGoogle();
  Future<void> deconnecter();

  /// À appeler avant d'effacer quoi que ce soit : si la dernière connexion
  /// est trop ancienne pour que Firebase accepte la suppression du compte,
  /// redemande le compte Google. Lève [ConnexionEchouee] si l'utilisateur
  /// renonce ou si la vérification échoue : rien ne doit alors être effacé.
  Future<void> preparerSuppression();

  /// Supprime le compte d'authentification (après l'effacement des données).
  /// Redemande une connexion Google si la dernière est trop ancienne.
  Future<void> supprimerCompte();

  /// Jeton d'identité pour le relais (null si non connecté).
  Future<String?> jeton();
}

/// Firebase refuse de supprimer un compte dont la dernière connexion date de
/// plus de 5 minutes ; une marge laisse le temps d'effacer les données.
const delaiConnexionRecente = Duration(minutes: 4);

/// Vrai s'il faut redemander le compte Google avant une suppression.
bool reconnexionNecessaire(DateTime? derniere, DateTime maintenant) =>
    derniere == null || maintenant.difference(derniere) > delaiConnexionRecente;

/// Identifiant OAuth « Web » du projet Firebase (client_type 3 de
/// google-services.json), exigé par Google pour délivrer un jeton à Firebase.
const _serverClientId =
    '67566402702-0smaeibd2fn2fn27u955hu9tmcj4md0f.apps.googleusercontent.com';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _initialisation;

  static Utilisateur? _versUtilisateur(User? u) => u == null
      ? null
      : Utilisateur(uid: u.uid, prenom: _prenom(u.displayName));

  static String? _prenom(String? nomComplet) {
    final mots = nomComplet?.trim().split(RegExp(r'\s+')) ?? const [];
    return mots.isEmpty || mots.first.isEmpty ? null : mots.first;
  }

  @override
  Stream<Utilisateur?> get changements =>
      _auth.authStateChanges().map(_versUtilisateur);

  @override
  Utilisateur? get actuel => _versUtilisateur(_auth.currentUser);

  Future<void> _initialiser() =>
      _initialisation ??= _google.initialize(serverClientId: _serverClientId);

  @override
  Future<Utilisateur?> connecterGoogle() async {
    try {
      await _initialiser();
      final compte = await _google.authenticate();
      final idToken = compte.authentication.idToken;
      if (idToken == null) throw const ConnexionEchouee('idToken absent');
      final resultat = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _versUtilisateur(resultat.user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ConnexionEchouee(e);
    } on ConnexionEchouee {
      rethrow;
    } catch (e) {
      throw ConnexionEchouee(e);
    }
  }

  /// Redemande le compte Google et renouvelle la connexion de [u] ;
  /// toute erreur, annulation comprise, devient [ConnexionEchouee].
  Future<void> _reauthentifier(User u) async {
    try {
      await _initialiser();
      final compte = await _google.authenticate();
      final idToken = compte.authentication.idToken;
      if (idToken == null) throw const ConnexionEchouee('idToken absent');
      await u.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on ConnexionEchouee {
      rethrow;
    } catch (e) {
      throw ConnexionEchouee(e);
    }
  }

  @override
  Future<void> preparerSuppression() async {
    final u = _auth.currentUser;
    if (u == null) throw const ConnexionEchouee('non connecté');
    if (reconnexionNecessaire(u.metadata.lastSignInTime, DateTime.now())) {
      await _reauthentifier(u);
    }
  }

  @override
  Future<void> supprimerCompte() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await u.delete();
    } on FirebaseAuthException catch (e) {
      // Filet de sécurité : l'effacement a duré plus que prévu.
      if (e.code != 'requires-recent-login') throw ConnexionEchouee(e);
      await _reauthentifier(u);
      try {
        await u.delete();
      } catch (e) {
        throw ConnexionEchouee(e);
      }
    }
    try {
      await _google.signOut();
    } catch (_) {
      // Le compte n'existe plus : la session Google locale est sans importance.
    }
  }

  @override
  Future<String?> jeton() async => _auth.currentUser?.getIdToken();

  @override
  Future<void> deconnecter() async {
    await _initialiser();
    await _google.signOut();
    await _auth.signOut();
  }
}
