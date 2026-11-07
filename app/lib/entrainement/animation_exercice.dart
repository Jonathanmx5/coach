import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';

/// Exercices pour lesquels on a deux photos (début et fin du mouvement) dans
/// assets/exercices/ : {id}_0.jpg et {id}_1.jpg. Photos du jeu libre de droits
/// « free-exercise-db » (licence Unlicense, domaine public).
const exercicesAnimes = {
  'squat',
  'squat_halteres',
  'presse_cuisses',
  'fentes',
  'fentes_halteres',
  'pont_fessier',
  'souleve_terre_halteres',
  'swing_kettlebell',
  'pompes_genoux',
  'pompes',
  'developpe_halteres',
  'developpe_couche',
  'dips_chaise',
  'superman',
  'tirage_elastique',
  'rowing_halteres',
  'tractions',
  'tirage_vertical',
  'planche',
  'gainage_lateral',
  'crunch',
  'dead_bug',
  'corde',
  'mountain_climbers',
  'jumping_jacks',
  'montees_genoux',
  'marche_genoux',
  'talons_fesses',
  'squat_saute',
  'pont_unijambiste',
  'kickback_fessier',
  'pompes_serrees',
  'rotation_russe',
  'battements_jambes',
  'crunch_inverse',
  'crunch_croise',
  'velo_abdos',
  'elevations_laterales',
  'developpe_epaules',
  'developpe_incline_halteres',
  'extension_triceps',
  'kickback_triceps',
  'curl_biceps',
  'curl_marteau',
  'oiseau',
  'rowing_assis',
  'face_pull',
  'leg_curl',
  'dips_barres',
  'extension_triceps_poulie',
  // Étirements et mobilité
  'etir_quadriceps',
  'etir_ischios',
  'etir_fessiers',
  'etir_mollets',
  'etir_pectoraux',
  'etir_epaules',
  'posture_enfant',
  'cercles_nuque',
  'cercles_epaules',
  'chat_vache',
  'rotation_buste',
  'fente_basse',
  'squat_profond',
  'genoux_poitrine',
  'torsion_allongee',
};

/// Exercices qui ont une vidéo dans assets/videos/{id}.mp4 : extraits de
/// wger (CC BY-SA 4.0), préparés par tool/telecharger_videos.mjs. Les photos
/// restent dessous : elles s'affichent tant que la vidéo n'est pas prête, ou
/// si elle ne peut pas être lue.
const exercicesVideo = {
  'developpe_couche',
  'developpe_halteres',
  'fentes_halteres',
  'presse_cuisses',
  'souleve_terre_halteres',
  'elevations_laterales',
  'developpe_epaules',
  'developpe_incline_halteres',
  'extension_triceps',
  'kickback_triceps',
  'curl_biceps',
  'curl_marteau',
  'oiseau',
  'rowing_assis',
  'face_pull',
  'leg_curl',
  'dips_barres',
  'extension_triceps_poulie',
};

/// Montre le mouvement d'un exercice : les deux positions se fondent l'une
/// dans l'autre en boucle. Ne dessine rien si on n'a pas de photos.
class AnimationExercice extends StatefulWidget {
  const AnimationExercice({
    super.key,
    required this.exerciceId,
    this.hauteur,
    this.arrondi = 16,
    this.video = false,
  });

  final String exerciceId;

  /// Lit la vidéo de l'exercice quand elle existe. Réservé au grand format
  /// de la séance : les vignettes d'une liste restent en photos.
  final bool video;

  /// Hauteur imposée ; sinon les photos gardent leur rapport 3:2.
  final double? hauteur;
  final double arrondi;

  @override
  State<AnimationExercice> createState() => _AnimationExerciceState();
}

class _AnimationExerciceState extends State<AnimationExercice> {
  Timer? _minuteur;
  bool _fin = false;

  bool get _disponible => exercicesAnimes.contains(widget.exerciceId);

  @override
  void initState() {
    super.initState();
    if (_disponible) {
      _minuteur = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _fin = !_fin);
      });
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Widget _image(int i) => Image.asset(
    'assets/exercices/${widget.exerciceId}_$i.jpg',
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) =>
        const ColoredBox(color: Color(0xFFE1F5EE), child: SizedBox.expand()),
  );

  @override
  Widget build(BuildContext context) {
    if (!_disponible) return const SizedBox.shrink();
    final contenu = ClipRRect(
      borderRadius: BorderRadius.circular(widget.arrondi),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 600),
        sizeCurve: Curves.linear,
        crossFadeState: _fin
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        layoutBuilder: (haut, cleHaut, bas, cleBas) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(key: cleBas, child: bas),
            Positioned.fill(key: cleHaut, child: haut),
          ],
        ),
        firstChild: _image(0),
        secondChild: _image(1),
      ),
    );
    final avecVideo = widget.video && exercicesVideo.contains(widget.exerciceId)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(widget.arrondi),
            child: Stack(
              fit: StackFit.expand,
              children: [contenu, _VideoExercice(widget.exerciceId)],
            ),
          )
        : contenu;
    return Semantics(
      image: true,
      label: AppLocalizations.of(context)!.demonstrationExercice,
      child: widget.hauteur != null
          ? SizedBox(height: widget.hauteur, child: avecVideo)
          : AspectRatio(aspectRatio: 3 / 2, child: avecVideo),
    );
  }
}

/// Vidéo muette en boucle, recadrée pour remplir la place. Rien tant qu'elle
/// n'est pas prête ou si la lecture échoue : les photos dessous restent.
class _VideoExercice extends StatefulWidget {
  const _VideoExercice(this.id);

  final String id;

  @override
  State<_VideoExercice> createState() => _VideoExerciceState();
}

class _VideoExerciceState extends State<_VideoExercice> {
  late final VideoPlayerController _lecteur = VideoPlayerController.asset(
    'assets/videos/${widget.id}.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _prete = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    try {
      await _lecteur.initialize();
      await _lecteur.setVolume(0);
      await _lecteur.setLooping(true);
      await _lecteur.play();
      if (mounted) setState(() => _prete = true);
    } catch (_) {
      // Pas de lecteur (tests, appareil sans décodeur) : les photos suffisent.
    }
  }

  @override
  void dispose() {
    _lecteur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_prete) return const SizedBox.shrink();
    final taille = _lecteur.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: taille.width,
        height: taille.height,
        child: VideoPlayer(_lecteur),
      ),
    );
  }
}
