import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../compte/auth_service.dart';
import '../compte/donnees_compte.dart';
import '../l10n/app_localizations.dart';
import '../sauvegarde/fichiers.dart';
import '../sauvegarde/sauvegarde.dart';
import '../services.dart';
import '../theme.dart';
import 'mises_a_jour.dart';

typedef OuvreurLien = Future<bool> Function(Uri adresse);

/// Version installée, mise à jour proposée, QR code de partage, données
/// partagées, déconnexion et suppression du compte.
class ReglagesPage extends StatefulWidget {
  const ReglagesPage({
    super.key,
    required this.utilisateur,
    required this.services,
    required this.version,
    required this.miseAJour,
    required this.reverifier,
  });

  final Utilisateur utilisateur;
  final Services services;
  final Future<String> version;

  /// Mise à jour disponible (null si aucune) ; mis à jour par [reverifier].
  final ValueListenable<InfoMiseAJour?> miseAJour;
  final Future<void> Function() reverifier;

  @override
  State<ReglagesPage> createState() => _ReglagesPageState();
}

class _ReglagesPageState extends State<ReglagesPage> {
  bool _verification = false;
  bool _verifie = false;
  bool _suppression = false;

  Services get _s => widget.services;
  String get _uid => widget.utilisateur.uid;

  Future<void> _verifier() async {
    setState(() {
      _verification = true;
      _verifie = false;
    });
    await widget.reverifier();
    if (mounted) {
      setState(() {
        _verification = false;
        _verifie = true;
      });
    }
  }

  Future<void> _copier(AppLocalizations t) async {
    await Clipboard.setData(const ClipboardData(text: lienPartage));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t.lienCopie)));
  }

  Future<void> _deconnecter() async {
    // La page se ferme d'abord : l'aiguillage de l'appli reprend la main.
    Navigator.of(context).pop();
    await _s.auth.deconnecter();
  }

  bool _sauvegarde = false;

  Future<void> _exporter() async {
    final t = AppLocalizations.of(context)!;
    // Hors ligne, seul le cache serait lu : la sauvegarde serait incomplète.
    final enLigne = await _s.reseau.enLigne.first;
    if (!enLigne) {
      if (mounted) _message(t.sauvegardeExportHorsLigne);
      return;
    }
    if (!mounted) return;
    setState(() => _sauvegarde = true);
    try {
      final octets = await _s.sauvegarde.exporter(
        _uid,
        maintenant: DateTime.now(),
      );
      final jour = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fait = await _s.fichiers.enregistrer(
        'crunch-and-go-$jour.xlsx',
        octets,
      );
      if (mounted && fait) _message(t.sauvegardeEnregistree);
    } catch (_) {
      if (mounted) _message(t.sauvegardeEchec);
    } finally {
      if (mounted) setState(() => _sauvegarde = false);
    }
  }

  Future<void> _importer() async {
    final t = AppLocalizations.of(context)!;
    final enLigne = await _s.reseau.enLigne.first;
    if (!enLigne) {
      if (mounted) _message(t.sauvegardeHorsLigne);
      return;
    }
    final Uint8List? octets;
    try {
      octets = await _s.fichiers.choisir();
    } on FichierTropGros {
      if (mounted) _message(t.importTropGros);
      return;
    } catch (_) {
      if (mounted) _message(t.importLectureEchec);
      return;
    }
    if (octets == null || !mounted) return;
    var remplacer = false;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, majDialogue) => AlertDialog(
          title: Text(t.importConfirmerTitre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.importConfirmerTexte),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: remplacer,
                onChanged: (v) => majDialogue(() => remplacer = v ?? false),
                title: Text(t.importRemplacer),
                subtitle: Text(t.importRemplacerAide),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.annuler),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.importer),
            ),
          ],
        ),
      ),
    );
    if (confirme != true || !mounted) return;
    setState(() => _sauvegarde = true);
    try {
      final r = await _s.sauvegarde.importer(
        _uid,
        octets,
        maintenant: DateTime.now(),
        remplacer: remplacer,
      );
      if (mounted) await _resultatImport(t, r);
    } on SauvegardeInvalide {
      if (mounted) _message(t.importInvalide);
    } catch (_) {
      if (mounted) _message(t.importEchec);
    } finally {
      if (mounted) setState(() => _sauvegarde = false);
    }
  }

  /// Un import sans accroc tient dans un message ; sinon, une fenêtre dit ce
  /// qui est déjà écrit et pourquoi des lignes ont été laissées de côté.
  Future<void> _resultatImport(AppLocalizations t, ResultatImport r) async {
    final bilan = [
      t.importTermine(r.importes, r.ignores.length),
      if (r.dejaPresents > 0) t.importDejaPresents(r.dejaPresents),
    ].join(' ');
    if (r.erreur == null && r.ignores.isEmpty) {
      _message(bilan);
      return;
    }
    const montres = 5;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          r.erreur == null ? t.importResultatTitre : t.importInterrompuTitre,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bilan),
              if (r.erreur != null) ...[
                const SizedBox(height: 8),
                Text(
                  r.erreur == ErreurImport.refus
                      ? t.importRefuse
                      : t.importInterrompu,
                ),
              ],
              if (r.ignores.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(t.importLignesIgnorees),
                for (final m in r.ignores.take(montres)) Text('• $m'),
                if (r.ignores.length > montres)
                  Text(t.importAutresMotifs(r.ignores.length - montres)),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _nettoyerPhotos() async {
    final t = AppLocalizations.of(context)!;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.photosRepasNettoyer),
        content: Text(t.photosRepasNettoyerAide),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.annuler),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.supprimer),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    final n = await _s.photosRepas.supprimerAvant(
      DateTime.now().subtract(const Duration(days: 90)),
    );
    if (!mounted) return;
    setState(() {});
    _message(t.photosRepasNettoyees(n));
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _supprimerCompte() async {
    final t = AppLocalizations.of(context)!;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.supprimerCompteTitre),
        content: Text(t.supprimerCompteTexte),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.annuler),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.supprimerConfirmer),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    // L'effacement passe par le réseau : sans lui, il resterait en attente.
    final enLigne = await _s.reseau.enLigne.first;
    if (!enLigne) {
      if (mounted) _message(t.supprimerHorsLigne);
      return;
    }
    setState(() => _suppression = true);
    try {
      await _s.donnees.supprimerTout(_uid);
      for (final p in await _s.photos.lister()) {
        await _s.photos.supprimer(p);
      }
      await _s.photosRepas.toutSupprimer();
      // Copies d'une sauvegarde importée restées dans le cache.
      await _s.fichiers.nettoyer();
      await _s.rappels.planifier(const []);
      await _s.auth.supprimerCompte();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _suppression = false);
        _message(t.supprimerEchec);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    if (_suppression) {
      return Scaffold(
        appBar: AppBar(title: Text(t.reglagesTitre)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(t.supprimerEnCours),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.reglagesTitre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: widget.version,
                    builder: (context, snap) => Text(
                      t.versionNumero(snap.data ?? '…'),
                      style: textes.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<InfoMiseAJour?>(
                    valueListenable: widget.miseAJour,
                    builder: (context, maj, _) => maj == null
                        ? Text(
                            _verifie ? t.majAJour : t.majAideVerifier,
                            style: textes.bodyMedium?.copyWith(
                              color: context.palette.texteDoux,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.palette.orangeClair,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.majDisponible(maj.version),
                                  style: textes.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () => _s.ouvrirLien(maj.page),
                                  icon: const Icon(Icons.download),
                                  label: Text(t.majTelecharger),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _verification ? null : _verifier,
                    icon: _verification
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(t.majVerifier),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(t.partagerTitre, style: textes.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    t.partagerAide,
                    textAlign: TextAlign.center,
                    style: textes.bodySmall?.copyWith(
                      color: context.palette.texteDoux,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: QrImageView(
                      data: lienPartage,
                      size: 200,
                      semanticsLabel: t.partagerTitre,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _copier(t),
                    icon: const Icon(Icons.copy),
                    label: Text(t.copierLien),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t.apparence, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: _s.theme.mode,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(t.themeClair),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(t.themeSombre),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(t.themeAuto),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => unawaited(_s.theme.definir(s.first)),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Set<Consentement>>(
            stream: _s.consentements.accordes(_uid),
            builder: (context, snap) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.consentPhotoReglage),
              subtitle: Text(t.consentPhotoReglageAide),
              value: snap.data?.contains(Consentement.photo) ?? false,
              onChanged: (v) => unawaited(
                _s.consentements.definir(_uid, Consentement.photo, v),
              ),
            ),
          ),
          Text(
            t.sauvegardeTitre,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_download_outlined),
            title: Text(t.sauvegardeExporter),
            subtitle: Text(t.sauvegardeExporterAide),
            enabled: !_sauvegarde,
            onTap: _exporter,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(t.sauvegardeImporter),
            subtitle: Text(t.sauvegardeImporterAide),
            enabled: !_sauvegarde,
            onTap: _importer,
          ),
          FutureBuilder<({int nombre, int octets})>(
            future: _s.photosRepas.bilan(),
            builder: (context, snap) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.photosRepasTitre),
              subtitle: snap.data == null
                  ? null
                  : Text(
                      t.photosRepasBilan(
                        snap.data!.nombre,
                        (snap.data!.octets / 1048576).toStringAsFixed(1),
                      ),
                    ),
              trailing: const Icon(Icons.cleaning_services_outlined),
              onTap: _nettoyerPhotos,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.confidentialite),
            onTap: () => _s.ouvrirLien(Uri.parse(lienConfidentialite)),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(t.boutonDeconnexion),
            subtitle: widget.utilisateur.prenom == null
                ? null
                : Text(widget.utilisateur.prenom!),
            onTap: _deconnecter,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              t.supprimerCompte,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _supprimerCompte,
          ),
        ],
      ),
    );
  }
}
