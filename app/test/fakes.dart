import 'dart:async';

import 'package:coach/compte/auth_service.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';

/// Connexion programmable : [reponse] décide du résultat de connecterGoogle.
class FauxAuth implements AuthService {
  FauxAuth({Utilisateur? connecte, this.reponse}) : _actuel = connecte;

  Future<Utilisateur?> Function()? reponse;
  Utilisateur? _actuel;
  final _flux = StreamController<Utilisateur?>.broadcast();

  @override
  Utilisateur? get actuel => _actuel;

  @override
  Stream<Utilisateur?> get changements async* {
    yield _actuel;
    yield* _flux.stream;
  }

  @override
  Future<Utilisateur?> connecterGoogle() async {
    final u = await (reponse ?? () async => null)();
    if (u != null) {
      _actuel = u;
      _flux.add(u);
    }
    return u;
  }

  @override
  Future<void> deconnecter() async {
    _actuel = null;
    _flux.add(null);
  }
}

/// Stockage en mémoire. Avec [bloquerEnregistrement], `enregistrer` publie la
/// donnée (comme le cache Firestore) mais ne se termine jamais (hors-ligne).
class FauxDepot implements ProfilRepository {
  FauxDepot({this.bloquerEnregistrement = false});

  final bool bloquerEnregistrement;
  final donnees = <String, ProfilEnregistre>{};
  final _flux = StreamController<String>.broadcast();

  @override
  Stream<ProfilEnregistre?> observer(String uid) async* {
    yield donnees[uid];
    yield* _flux.stream.where((u) => u == uid).map((_) => donnees[uid]);
  }

  @override
  Future<void> enregistrer(String uid, Profil p, Reperes r) {
    donnees[uid] = ProfilEnregistre(profil: p, reperes: r);
    _flux.add(uid);
    return bloquerEnregistrement ? Completer<void>().future : Future.value();
  }
}
