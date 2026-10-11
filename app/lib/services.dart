import 'compte/auth_service.dart';
import 'entrainement/entrainement_repository.dart';
import 'entrainement/voix.dart';
import 'journal/catalogue.dart';
import 'journal/journal_repository.dart';
import 'poids/mensurations_repository.dart';
import 'poids/pesees_repository.dart';
import 'poids/photos.dart';
import 'profil/profil_repository.dart';
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
  final JournalRepository journal;
  final CatalogueProduits catalogue;
  final SanteService sante;
}
