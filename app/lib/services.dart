import 'bienetre/bienetre_repository.dart';
import 'bienetre/meteo.dart';
import 'bienetre/rappels.dart';
import 'compte/auth_service.dart';
import 'compte/donnees_compte.dart';
import 'entrainement/entrainement_repository.dart';
import 'entrainement/voix.dart';
import 'journal/analyse_photo.dart';
import 'journal/journal_repository.dart';
import 'poids/mensurations_repository.dart';
import 'poids/pesees_repository.dart';
import 'journal/catalogue.dart';
import 'journal/photos_repas.dart';
import 'reglages/reglage_rapports.dart';
import 'reglages/reglage_theme.dart';
import 'sauvegarde/fichiers.dart';
import 'sauvegarde/sauvegarde.dart';
import 'poids/photos.dart';
import 'profil/profil_repository.dart';
import 'recettes/avis_repository.dart';
import 'recettes/planning_repository.dart';
import 'reglages/mises_a_jour.dart';
import 'reglages/reglages_page.dart';
import 'reseau.dart';
import 'widget/donnees_widget.dart';
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
    required this.catalogue,
    required this.photosRepas,
    required this.theme,
    required this.rapports,
    required this.sauvegarde,
    required this.fichiers,
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
    required this.widgetAccueil,
    required this.journal,
    required this.sante,
  });

  final AuthService auth;
  final ProfilRepository depot;
  final PeseesRepository pesees;
  final MensurationsRepository mensurations;
  final PhotosProgres photos;
  final CatalogueProduits catalogue;
  final PhotosRepas photosRepas;
  final ReglageTheme theme;

  /// Envoi des rapports de plantage, choisi dans les Réglages.
  final ReglageRapports rapports;
  final Sauvegarde sauvegarde;
  final Fichiers fichiers;
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
  final MiseAJourWidget widgetAccueil;
  final JournalRepository journal;
  final SanteService sante;
}
