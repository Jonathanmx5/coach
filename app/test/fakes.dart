import 'dart:async';

import 'package:coach/compte/auth_service.dart';
import 'package:coach/entrainement/entrainement_repository.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/entrainement/voix.dart';
import 'package:coach/journal/catalogue.dart';
import 'package:coach/journal/journal_repository.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/poids/mensurations.dart';
import 'package:coach/poids/mensurations_repository.dart';
import 'package:coach/poids/pesees.dart';
import 'package:coach/poids/photos.dart';
import 'package:coach/poids/pesees_repository.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/sante/modele.dart';
import 'package:coach/sante/sante_service.dart';

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

/// Health Connect simulé.
class FauxSante implements SanteService {
  FauxSante({
    this.dispo = DispoSante.disponible,
    this.accorde = true,
    List<PointSante>? points,
  }) : points = points ?? [];

  DispoSante dispo;
  bool accorde;
  List<PointSante> points;
  int autorisationsDemandees = 0;
  int installations = 0;

  @override
  Future<DispoSante> disponibilite() async => dispo;

  @override
  Future<void> installer() async => installations++;

  @override
  Future<bool> demanderAutorisations() async {
    autorisationsDemandees++;
    return accorde;
  }

  @override
  Future<List<PointSante>> lire(
    DateTime debut,
    DateTime fin, {
    Set<TypeMesure>? types,
  }) async => [
    for (final p in points)
      if (!p.fin.isBefore(debut) &&
          !p.debut.isAfter(fin) &&
          (types == null || types.contains(p.type)))
        p,
  ];
}

/// Pesées saisies, en mémoire.
class FauxPesees implements PeseesRepository {
  final donnees = <String, List<Pesee>>{};
  final _flux = StreamController<String>.broadcast();
  var _compteur = 0;

  List<Pesee> de(String uid) => donnees[uid] ?? const [];

  @override
  Stream<List<Pesee>> observer(String uid) async* {
    yield de(uid);
    yield* _flux.stream.where((u) => u == uid).map((_) => de(uid));
  }

  @override
  Future<void> ajouter(
    String uid, {
    required double kg,
    required DateTime date,
  }) async {
    final liste = [
      ...de(uid),
      Pesee(
        id: 'p${_compteur++}',
        date: date,
        kg: kg,
        source: SourcePesee.manuel,
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    donnees[uid] = liste;
    _flux.add(uid);
  }

  @override
  Future<void> supprimer(String uid, String id) async {
    donnees[uid] = [
      for (final p in de(uid))
        if (p.id != id) p,
    ];
    _flux.add(uid);
  }
}

/// Voix qui note ce qu'elle aurait dit.
class FausseVoix implements Voix {
  final dits = <String>[];

  @override
  Future<void> dire(String texte) async => dits.add(texte);

  @override
  Future<void> arreter() async {}
}

/// Réglages et séances d'entraînement en mémoire.
class FauxEntrainement implements EntrainementRepository {
  final reglagesParUid = <String, Reglages>{};
  final seancesParUid = <String, List<SeanceFaite>>{};
  final _flux = StreamController<void>.broadcast();

  Reglages reglagesDe(String uid) => reglagesParUid[uid] ?? const Reglages();
  List<SeanceFaite> seancesDe(String uid) => seancesParUid[uid] ?? const [];

  @override
  Stream<Reglages> reglages(String uid) async* {
    yield reglagesDe(uid);
    yield* _flux.stream.map((_) => reglagesDe(uid));
  }

  @override
  Stream<List<SeanceFaite>> seances(String uid) async* {
    yield seancesDe(uid);
    yield* _flux.stream.map((_) => seancesDe(uid));
  }

  @override
  Future<void> enregistrerReglages(String uid, Reglages r) async {
    reglagesParUid[uid] = r;
    _flux.add(null);
  }

  @override
  Future<void> ajouterSeance(String uid, SeanceFaite s) async {
    seancesParUid[uid] = [...seancesDe(uid), s];
    _flux.add(null);
  }
}

/// Photos de progression en mémoire (aucun fichier réel).
class FausPhotos implements PhotosProgres {
  final liste = <PhotoProgres>[];
  var annule = false;

  @override
  Future<List<PhotoProgres>> lister() async => [...liste];

  @override
  Future<PhotoProgres?> prendre(DateTime date) async {
    if (annule) return null;
    final p = PhotoProgres(
      chemin: '/faux/${date.millisecondsSinceEpoch}.jpg',
      date: date,
    );
    liste.add(p);
    return p;
  }

  @override
  Future<void> supprimer(PhotoProgres photo) async => liste.remove(photo);
}

/// Mensurations en mémoire.
class FauxMensurations implements MensurationsRepository {
  final donnees = <String, List<Mensuration>>{};
  final _flux = StreamController<String>.broadcast();
  var _compteur = 0;

  List<Mensuration> de(String uid) => donnees[uid] ?? const [];

  @override
  Stream<List<Mensuration>> observer(String uid) async* {
    yield de(uid);
    yield* _flux.stream.where((u) => u == uid).map((_) => de(uid));
  }

  @override
  Future<void> ajouter(String uid, Mensuration m) async {
    donnees[uid] = [
      ...de(uid),
      Mensuration(id: 'm${_compteur++}', date: m.date, valeurs: m.valeurs),
    ]..sort((a, b) => a.date.compareTo(b.date));
    _flux.add(uid);
  }

  @override
  Future<void> supprimer(String uid, String id) async {
    donnees[uid] = [
      for (final m in de(uid))
        if (m.id != id) m,
    ];
    _flux.add(uid);
  }
}

/// Journal en mémoire (repas et activités).
class FauxJournal implements JournalRepository {
  final repasParUid = <String, List<Repas>>{};
  final activitesParUid = <String, List<Activite>>{};
  final _flux = StreamController<void>.broadcast();
  var _compteur = 0;

  List<Repas> repasDe(String uid) => repasParUid[uid] ?? const [];
  List<Activite> activitesDe(String uid) => activitesParUid[uid] ?? const [];

  Stream<T> _suivre<T>(T Function() lire) async* {
    yield lire();
    yield* _flux.stream.map((_) => lire());
  }

  bool _dans(DateTime d, DateTime debut, DateTime fin) =>
      !d.isBefore(debut) && d.isBefore(fin);

  @override
  Stream<List<Repas>> repas(String uid, DateTime debut, DateTime fin) =>
      _suivre(
        () => [
          for (final r in repasDe(uid))
            if (_dans(r.date, debut, fin)) r,
        ]..sort((a, b) => a.date.compareTo(b.date)),
      );

  @override
  Stream<List<Activite>> activites(String uid, DateTime debut, DateTime fin) =>
      _suivre(
        () => [
          for (final a in activitesDe(uid))
            if (_dans(a.date, debut, fin)) a,
        ]..sort((a, b) => a.date.compareTo(b.date)),
      );

  @override
  Future<void> ajouterRepas(String uid, Repas repas) async {
    repasParUid[uid] = [
      ...repasDe(uid),
      Repas(
        id: 'r${_compteur++}',
        date: repas.date,
        moment: repas.moment,
        nom: repas.nom,
        macros: repas.macros,
        source: repas.source,
      ),
    ];
    _flux.add(null);
  }

  @override
  Future<void> supprimerRepas(String uid, String id) async {
    repasParUid[uid] = [
      for (final r in repasDe(uid))
        if (r.id != id) r,
    ];
    _flux.add(null);
  }

  @override
  Future<void> ajouterActivite(String uid, Activite activite) async {
    activitesParUid[uid] = [
      ...activitesDe(uid),
      Activite(
        id: 'a${_compteur++}',
        date: activite.date,
        type: activite.type,
        minutes: activite.minutes,
        intensite: activite.intensite,
        kcal: activite.kcal,
      ),
    ];
    _flux.add(null);
  }

  @override
  Future<void> supprimerActivite(String uid, String id) async {
    activitesParUid[uid] = [
      for (final a in activitesDe(uid))
        if (a.id != id) a,
    ];
    _flux.add(null);
  }
}

/// Catalogue de produits programmable.
class FauxCatalogue implements CatalogueProduits {
  FauxCatalogue({this.produit, this.erreur = false});

  ProduitOff? produit;
  bool erreur;
  final recherches = <String>[];

  @override
  Future<ProduitOff?> chercher(String codeBarres) async {
    recherches.add(codeBarres);
    if (erreur) throw const ErreurCatalogue('hors-ligne');
    return produit;
  }
}
