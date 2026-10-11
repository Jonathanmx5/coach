import 'bienetre/bienetre_repository.dart';
import 'bienetre/meteo.dart';
import 'bienetre/rappels.dart';
import 'compte/auth_service.dart';
import 'compte/donnees_compte.dart';
import 'entrainement/entrainement_repository.dart';
import 'entrainement/voix.dart';
import 'journal/analyse_photo.dart';
import 'journal/catalogue.dart';
import 'journal/journal_repository.dart';
import 'poids/mensurations_repository.dart';
import 'poids/pesees_repository.dart';
import 'poids/photos.dart';
import 'profil/profil_repository.dart';
import 'recettes/avis_repository.dart';
import 'recettes/planning_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reglages/reglages_page.dart';
import 'reseau.dart';
import 'sante/sante_service.dart';

/// Tout ce que l'appli utilise à l'extérieur (Firebase, Health Connect,
/// Open Food Facts…), regroupé pour être remplacé par des faux dans les tests.
class Services {
  const Services({
    required this.auth,
    required this.depot,
    required this.pesees,
    required this.mensurations,
    required this.photos,
    required this.entrainement,
    required this.voix,
    required this.bienetre,
    required this.meteo,
    required this.rappels,
    required this.reseau,
    required this.analyse,
    required this.planning,
    required this.avis,
    required this.miseAJour,
    required this.versionAppli,
    required this.ouvrirLien,
    required this.donnees,
    required this.consentements,
    required this.journal,
    required this.catalogue,
    required this.sante,
  });

  final AuthService auth;
  final ProfilRepository depot;
  final PeseesRepository pesees;
  final MensurationsRepository mensurations;
  final PhotosProgres photos;
  final EntrainementRepository entrainement;
  final Voix voix;
  final BienEtreRepository bienetre;
  final Meteo meteo;
  final Rappels rappels;
  final Reseau reseau;
  final AnalysePhoto analyse;
  final PlanningRepository planning;
  final AvisRepository avis;
  final MisesAJour miseAJour;
  final VersionAppli versionAppli;
  final OuvreurLien ouvrirLien;
  final DonneesCompte donnees;
  final ConsentementsRepository consentements;
  final JournalRepository journal;
  final CatalogueProduits catalogue;
  final SanteService sante;
}
