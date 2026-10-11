import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'photos.dart';

Widget _image(PhotoProgres p, {BoxFit fit = BoxFit.cover}) => Image.file(
  File(p.chemin),
  fit: fit,
  errorBuilder: (_, _, _) => const ColoredBox(
    color: CouleursCoach.vertPale,
    child: Center(child: Icon(Icons.image_outlined)),
  ),
);

/// Photos mensuelles « avant / après » : prise de vue, liste et comparaison.
class PhotosSection extends StatefulWidget {
  const PhotosSection({super.key, required this.photos, required this.horloge});

  final PhotosProgres photos;
  final DateTime Function() horloge;

  @override
  State<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends State<PhotosSection> {
  List<PhotoProgres> _liste = const [];

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  Future<void> _recharger() async {
    final l = await widget.photos.lister();
    if (mounted) setState(() => _liste = l);
  }

  Future<void> _prendre() async {
    await widget.photos.prendre(widget.horloge());
    await _recharger();
  }

  Future<void> _supprimer(PhotoProgres p) async {
    await widget.photos.supprimer(p);
    await _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.photosTitre, style: textes.titleMedium),
            const SizedBox(height: 4),
            Text(
              t.photosAide,
              style: textes.bodySmall?.copyWith(color: CouleursCoach.texteDoux),
            ),
            if (_liste.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in _liste)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 3 / 4,
                                  child: _image(p),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  DateFormat.yMMM('fr').format(p.date),
                                  style: textes.labelSmall,
                                ),
                                IconButton(
                                  tooltip: t.supprimerPhoto,
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 16,
                                  onPressed: () => _supprimer(p),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _prendre,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(t.prendrePhoto),
                ),
                if (_liste.length >= 2)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ComparaisonPage(photos: _liste),
                      ),
                    ),
                    icon: const Icon(Icons.compare),
                    label: Text(t.comparerPhotos),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Superpose deux photos : le curseur fait glisser de l'« avant » à l'« après ».
class ComparaisonPage extends StatefulWidget {
  const ComparaisonPage({super.key, required this.photos});

  final List<PhotoProgres> photos;

  @override
  State<ComparaisonPage> createState() => _ComparaisonPageState();
}

class _ComparaisonPageState extends State<ComparaisonPage> {
  late PhotoProgres _avant = widget.photos.first;
  late PhotoProgres _apres = widget.photos.last;
  double _opacite = 0.5;

  Widget _choix(PhotoProgres valeur, ValueChanged<PhotoProgres> quand) =>
      DropdownButton<PhotoProgres>(
        value: valeur,
        items: [
          for (final p in widget.photos)
            DropdownMenuItem(
              value: p,
              child: Text(DateFormat.yMMMd('fr').format(p.date)),
            ),
        ],
        onChanged: (p) => quand(p!),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.comparerPhotos)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _choix(_avant, (p) => setState(() => _avant = p)),
                _choix(_apres, (p) => setState(() => _apres = p)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(rayonCarte),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _image(_avant),
                    Opacity(opacity: _opacite, child: _image(_apres)),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Text(t.photoAvant),
                Expanded(
                  child: Slider(
                    value: _opacite,
                    onChanged: (v) => setState(() => _opacite = v),
                  ),
                ),
                Text(t.photoApres),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
