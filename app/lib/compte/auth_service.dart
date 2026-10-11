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

  /// Jeton d'identité pour le relais (null si non connecté).
  Future<String?> jeton();
}

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

  @override
  Future<String?> jeton() async => _auth.currentUser?.getIdToken();

  @override
  Future<void> deconnecter() async {
    await _initialiser();
    await _google.signOut();
    await _auth.signOut();
  }
}
