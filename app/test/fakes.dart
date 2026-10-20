import 'dart:async';
import 'dart:typed_data';

import 'package:coach/bienetre/bienetre_repository.dart';
import 'package:coach/bienetre/complements.dart';
import 'package:coach/bienetre/hydratation.dart';
import 'package:coach/bienetre/meteo.dart';
import 'package:coach/bienetre/rappels.dart';
import 'package:coach/compte/auth_service.dart';
import 'package:coach/compte/donnees_compte.dart';
import 'package:coach/entrainement/entrainement_repository.dart';
import 'package:coach/entrainement/modele.dart';
import 'package:coach/entrainement/voix.dart';
import 'package:coach/journal/analyse_photo.dart';
import 'package:coach/journal/journal_repository.dart';
import 'package:coach/journal/modele.dart';
import 'package:coach/poids/mensurations.dart';
import 'package:coach/poids/mensurations_repository.dart';
import 'package:coach/poids/pesees.dart';
import 'package:coach/journal/catalogue.dart';
import 'package:coach/sauvegarde/fichiers.dart';
import 'package:coach/sauvegarde/sauvegarde.dart';
import 'package:coach/journal/photos_repas.dart';
import 'package:coach/poids/photos.dart';
import 'package:coach/poids/pesees_repository.dart';
import 'package:coach/profil/besoins.dart';
import 'package:coach/profil/modele.dart';
import 'package:coach/profil/profil_repository.dart';
import 'package:coach/recettes/avis.dart';
import 'package:coach/recettes/avis_repository.dart';
import 'package:coach/recettes/planning.dart';
import 'package:coach/recettes/planning_repository.dart';
import 'package:coach/reglages/mises_a_jour.dart';
import 'package:coach/reseau.dart';
import 'package:coach/widget/donnees_widget.dart';
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

  bool compteSupprime = false;
  Object? echecSuppression;

  /// Réauthentification avant suppression : levée si renseignée (annulation).
  Object? echecPreparation;
  var preparations = 0;

  @override
  Future<void> preparerSuppression() async {
    preparations++;
    if (echecPreparation != null) throw echecPreparation!;
  }

  @override
  Future<void> supprimerCompte() async {
    if (echecSuppression != null) throw echecSuppression!;
    compteSupprime = true;
    _actuel = null;
    _flux.add(null);
  }

  @override
  Future<String?> jeton() async => _actuel == null ? null : 'jeton-test';

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

  /// Nombre de lectures demandées.
  int lectures = 0;

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
  }) async {
    lectures++;
    return [
      for (final p in points)
        if (!p.fin.isBefore(debut) &&
            !p.debut.isAfter(fin) &&
            (types == null || types.contains(p.type)))
          p,
    ];
  }
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

/// Analyse photo pilotée par le test.
class FausseAnalyse implements AnalysePhoto {
  FausseAnalyse({
    this.disponible = true,
    this.aliments = const [],
    this.description = '',
  });

  @override
  bool disponible;
  List<AlimentEstime> aliments;
  String description;
  CauseAnalyse? echec;
  int appels = 0;
  final indices = <String?>[];

  @override
  Future<ResultatAnalyse> analyser(Uint8List jpeg, {String? indice}) async {
    appels++;
    indices.add(indice);
    if (echec != null) throw AnalyseEchouee(echec!);
    return ResultatAnalyse(description: description, aliments: aliments);
  }
}

/// Avis sur les recettes en mémoire.
class FauxAvis implements AvisRepository {
  final parUid = <String, Map<String, Avis>>{};
  final _flux = StreamController<void>.broadcast();

  Map<String, Avis> de(String uid) => parUid[uid] ?? const {};

  @override
  Stream<Map<String, Avis>> avis(String uid) async* {
    yield de(uid);
    yield* _flux.stream.map((_) => de(uid));
  }

  @override
  Future<void> noter(String uid, String recetteId, Avis? avis) async {
    final copie = {...de(uid)};
    avis == null ? copie.remove(recetteId) : copie[recetteId] = avis;
    parUid[uid] = copie;
    _flux.add(null);
  }
}

/// Planning en mémoire.
class FauxPlanning implements PlanningRepository {
  final parSemaine = <String, Planning>{};
  final _flux = StreamController<void>.broadcast();

  String _cle(String uid, DateTime lundi) => '$uid/$lundi';

  @override
  Stream<Planning?> planning(String uid, DateTime lundi) async* {
    yield parSemaine[_cle(uid, lundi)];
    yield* _flux.stream.map((_) => parSemaine[_cle(uid, lundi)]);
  }

  @override
  Future<void> enregistrer(String uid, Planning p) async {
    parSemaine[_cle(uid, p.lundi)] = p;
    _flux.add(null);
  }
}

/// Version installée et mise à jour proposée, pilotées par le test.
class FausseVersion implements VersionAppli {
  @override
  Future<String> version() async => '0.9.0';
}

class FausseMiseAJour implements MisesAJour {
  FausseMiseAJour([this.info]);

  InfoMiseAJour? info;
  int verifications = 0;

  @override
  Future<InfoMiseAJour?> verifier(String versionActuelle) async {
    verifications++;
    return info;
  }
}

/// Effacement des données piloté par le test.
class FauxDonnees implements DonneesCompte {
  final supprimes = <String>[];
  bool echec = false;

  @override
  Future<void> supprimerTout(String uid) async {
    if (echec) throw StateError('refusé');
    supprimes.add(uid);
  }
}

/// Consentements en mémoire.
class FauxConsentements implements ConsentementsRepository {
  FauxConsentements([Set<Consentement> accordes = const {}])
    : _accordes = {...accordes};

  final Set<Consentement> _accordes;
  final _flux = StreamController<void>.broadcast();

  Set<Consentement> get accordesMaintenant => {..._accordes};

  @override
  Stream<Set<Consentement>> accordes(String uid) async* {
    yield {..._accordes};
    yield* _flux.stream.map((_) => {..._accordes});
  }

  @override
  Future<void> definir(String uid, Consentement c, bool accorde) async {
    accorde ? _accordes.add(c) : _accordes.remove(c);
    _flux.add(null);
  }
}

/// Widget de l'écran d'accueil : note ce qu'on lui envoie.
class FauxWidget implements MiseAJourWidget {
  final envois = <DonneesWidget>[];
  final jours = <DateTime>[];
  final uids = <String>[];
  int effacements = 0;
  final demandes = StreamController<String>.broadcast();
  String? lancement;

  @override
  Stream<String> get actions => demandes.stream;

  @override
  Future<String?> actionAuLancement() async => lancement;

  @override
  Future<void> mettre(
    DonneesWidget donnees, {
    required DateTime jour,
    required String uid,
  }) async {
    envois.add(donnees);
    jours.add(jour);
    uids.add(uid);
  }

  @override
  Future<void> effacer() async => effacements++;
}

/// Stockage du widget en mémoire. Écrire `null` retire la clé, comme
/// home_widget.
class FauxStockageWidget implements StockageWidget {
  final valeurs = <String, String?>{};

  /// Clés écrites, dans l'ordre (une écriture disque chacune sur Android).
  final ecritures = <String>[];
  int rafraichissements = 0;

  @override
  Future<String?> lire(String cle) async => valeurs[cle];

  @override
  Future<void> ecrire(String cle, String? valeur) async {
    ecritures.add(cle);
    if (valeur == null) {
      valeurs.remove(cle);
    } else {
      valeurs[cle] = valeur;
    }
  }

  @override
  Future<void> rafraichir() async => rafraichissements++;
}

/// Réseau piloté par le test.
class FauxReseau implements Reseau {
  FauxReseau([bool enLigne = true]) : _etat = enLigne;

  bool _etat;
  final _flux = StreamController<bool>.broadcast();

  void changer(bool enLigne) {
    _etat = enLigne;
    _flux.add(enLigne);
  }

  @override
  Stream<bool> get enLigne async* {
    yield _etat;
    yield* _flux.stream;
  }
}

/// Rappels qui notent la dernière planification.
class FauxRappels implements Rappels {
  bool accord = true;
  int autorisations = 0;
  final planifications = <List<Complement>>[];

  @override
  Future<bool> autoriser() async {
    autorisations++;
    return accord;
  }

  @override
  Future<void> planifier(List<Complement> complements) async =>
      planifications.add(complements);
}

/// Météo à température fixe (null = position refusée).
class FausseMeteo implements Meteo {
  FausseMeteo([this.temp]);

  double? temp;
  int appels = 0;

  @override
  Future<double?> temperatureMax() async {
    appels++;
    return temp;
  }
}

/// Eau, compléments et prises en mémoire.
class FauxBienEtre implements BienEtreRepository {
  final eauParUid = <String, List<EntreeEau>>{};
  final complementsParUid = <String, List<Complement>>{};
  final prisesParCle = <String, Set<String>>{};
  final meteo = <String, bool>{};
  final _flux = StreamController<void>.broadcast();
  var _compteur = 0;

  List<EntreeEau> eauDe(String uid) => eauParUid[uid] ?? const [];
  List<Complement> complementsDe(String uid) =>
      complementsParUid[uid] ?? const [];
  Set<String> prisesDe(String uid, DateTime j) =>
      prisesParCle['$uid/${cleJour(j)}'] ?? const {};

  Stream<T> _suivre<T>(T Function() lire) async* {
    yield lire();
    yield* _flux.stream.map((_) => lire());
  }

  @override
  Stream<List<EntreeEau>> eau(String uid, DateTime debut, DateTime fin) =>
      _suivre(
        () => [
          for (final e in eauDe(uid))
            if (!e.date.isBefore(debut) && e.date.isBefore(fin)) e,
        ]..sort((a, b) => a.date.compareTo(b.date)),
      );

  @override
  Stream<bool> meteoActive(String uid) => _suivre(() => meteo[uid] ?? false);

  @override
  Stream<List<Complement>> complements(String uid) => _suivre(
    () =>
        [...complementsDe(uid)]..sort((a, b) => a.minutes.compareTo(b.minutes)),
  );

  @override
  Stream<Set<String>> prises(String uid, DateTime jour) =>
      _suivre(() => {...prisesDe(uid, jour)});

  @override
  Future<void> ajouterEau(String uid, EntreeEau e) async {
    eauParUid[uid] = [
      ...eauDe(uid),
      EntreeEau(id: 'e${_compteur++}', date: e.date, ml: e.ml),
    ];
    _flux.add(null);
  }

  @override
  Future<void> supprimerEau(String uid, String id) async {
    eauParUid[uid] = [
      for (final e in eauDe(uid))
        if (e.id != id) e,
    ];
    _flux.add(null);
  }

  @override
  Future<void> activerMeteo(String uid, bool actif) async {
    meteo[uid] = actif;
    _flux.add(null);
  }

  @override
  Future<void> ajouterComplement(String uid, Complement c) async {
    complementsParUid[uid] = [
      ...complementsDe(uid),
      Complement(
        id: 'c${_compteur++}',
        nom: c.nom,
        minutes: c.minutes,
        actif: c.actif,
      ),
    ];
    _flux.add(null);
  }

  @override
  Future<void> modifierComplement(String uid, Complement c) async {
    complementsParUid[uid] = [
      for (final x in complementsDe(uid))
        if (x.id == c.id) c else x,
    ];
    _flux.add(null);
  }

  @override
  Future<void> supprimerComplement(String uid, String id) async {
    complementsParUid[uid] = [
      for (final x in complementsDe(uid))
        if (x.id != id) x,
    ];
    _flux.add(null);
  }

  @override
  Future<void> marquerPris(
    String uid,
    DateTime jour,
    String id,
    bool pris,
  ) async {
    final cle = '$uid/${cleJour(jour)}';
    final ids = {...prisesDe(uid, jour)};
    pris ? ids.add(id) : ids.remove(id);
    prisesParCle[cle] = ids;
    _flux.add(null);
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
  final ressentis = <String, int>{};
  final _flux = StreamController<void>.broadcast();

  String _cle(String uid, DateTime j) => '$uid/${j.year}-${j.month}-${j.day}';

  @override
  Stream<int?> ressenti(String uid, DateTime jour) async* {
    yield ressentis[_cle(uid, jour)];
    yield* _flux.stream.map((_) => ressentis[_cle(uid, jour)]);
  }

  @override
  Future<void> noterRessenti(String uid, DateTime jour, int valeur) async {
    ressentis[_cle(uid, jour)] = valeur;
    _flux.add(null);
  }

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

/// Sauvegarde Excel simulée.
class FausseSauvegarde implements Sauvegarde {
  final exports = <String>[];
  final imports = <Uint8List>[];
  final remplacements = <bool>[];
  bool invalide = false;

  /// Exception levée par [exporter] (lecture du serveur impossible...).
  Object? echecExport;
  var resultat = const ResultatImport(
    importes: 3,
    ignores: [Motif('Repas', 4, 'date invalide')],
  );

  @override
  Future<Uint8List> exporter(String uid, {required DateTime maintenant}) async {
    if (echecExport != null) throw echecExport!;
    exports.add(uid);
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<ResultatImport> importer(
    String uid,
    Uint8List octets, {
    required DateTime maintenant,
    bool remplacer = false,
  }) async {
    if (invalide) throw const SauvegardeInvalide();
    imports.add(octets);
    remplacements.add(remplacer);
    return resultat;
  }
}

/// Fichiers choisis ou enregistrés par le test.
class FauxFichiers implements Fichiers {
  final enregistres = <String, Uint8List>{};
  Uint8List? aChoisir;
  bool refuse = false;

  /// Exception levée par [choisir] (fichier trop gros, illisible...).
  Object? erreurChoix;
  var nettoyages = 0;

  @override
  Future<bool> enregistrer(String nom, Uint8List octets) async {
    if (refuse) return false;
    enregistres[nom] = octets;
    return true;
  }

  @override
  Future<Uint8List?> choisir() async {
    if (erreurChoix case final e?) throw e;
    return aChoisir;
  }

  @override
  Future<void> nettoyer() async => nettoyages++;

  var cachesVides = 0;

  @override
  Future<void> viderCache() async => cachesVides++;
}

/// Photos de repas en mémoire.
class FausPhotosRepas implements PhotosRepas {
  final photos = <String, Uint8List>{};
  var _n = 0;

  @override
  Future<String> enregistrer(Uint8List octets) async {
    final id = '${_n++}';
    photos[id] = octets;
    return id;
  }

  @override
  Future<Uint8List?> lire(String id) async => photos[id];

  @override
  Future<void> supprimer(String id) async => photos.remove(id);

  final dates = <String, DateTime>{};

  @override
  Future<({int nombre, int octets})> bilan() async => (
    nombre: photos.length,
    octets: photos.values.fold<int>(0, (s, p) => s + p.length),
  );

  @override
  Future<int> supprimerAvant(DateTime limite) async {
    final vieux = [
      for (final e in dates.entries)
        if (e.value.isBefore(limite)) e.key,
    ];
    for (final id in vieux) {
      photos.remove(id);
      dates.remove(id);
    }
    return vieux.length;
  }

  @override
  Future<void> toutSupprimer() async => photos.clear();
}

/// Photos de progression en mémoire (aucun fichier réel).
class FausPhotos implements PhotosProgres {
  final liste = <PhotoProgres>[];
  var annule = false;

  @override
  Future<List<PhotoProgres>> lister() async => [...liste];

  final ajouts = <({SourcePhoto source, DateTime jour})>[];

  @override
  Future<PhotoProgres?> ajouter(SourcePhoto source, DateTime jour) async {
    if (annule) return null;
    ajouts.add((source: source, jour: jour));
    final p = PhotoProgres(
      chemin: '/faux/${jour.millisecondsSinceEpoch}-${liste.length}.jpg',
      date: jour,
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

  /// Comme `set` de Firestore : un repas supprimé revient avec son id.
  @override
  Future<void> modifierRepas(String uid, Repas repas) async {
    final existe = repasDe(uid).any((r) => r.id == repas.id);
    repasParUid[uid] = [
      for (final r in repasDe(uid))
        if (r.id == repas.id) repas else r,
      if (!existe) repas,
    ];
    _flux.add(null);
  }

  /// Non nul : le prochain ajout de repas est refusé avec cette erreur.
  Object? refusAjout;

  @override
  Future<void> ajouterRepas(String uid, Repas repas) async {
    final refus = refusAjout;
    if (refus != null) {
      refusAjout = null;
      throw refus;
    }
    repasParUid[uid] = [
      ...repasDe(uid),
      Repas(
        id: 'r${_compteur++}',
        date: repas.date,
        moment: repas.moment,
        nom: repas.nom,
        macros: repas.macros,
        source: repas.source,
        description: repas.description,
        aliments: repas.aliments,
        photoId: repas.photoId,
        verdict: repas.verdict,
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
