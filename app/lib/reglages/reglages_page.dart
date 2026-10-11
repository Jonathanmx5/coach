import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'mises_a_jour.dart';

typedef OuvreurLien = Future<bool> Function(Uri adresse);

/// Version installée, mise à jour proposée, QR code de partage et
/// déconnexion.
class ReglagesPage extends StatefulWidget {
  const ReglagesPage({
    super.key,
    required this.utilisateur,
    required this.auth,
    required this.version,
    required this.miseAJour,
    required this.reverifier,
    required this.ouvrirLien,
  });

  final Utilisateur utilisateur;
  final AuthService auth;
  final Future<String> version;

  /// Mise à jour disponible (null si aucune) ; mis à jour par [reverifier].
  final ValueListenable<InfoMiseAJour?> miseAJour;
  final Future<void> Function() reverifier;
  final OuvreurLien ouvrirLien;

  @override
  State<ReglagesPage> createState() => _ReglagesPageState();
}

class _ReglagesPageState extends State<ReglagesPage> {
  bool _verification = false;
  bool _verifie = false;

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
    await widget.auth.deconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
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
                              color: CouleursCoach.texteDoux,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CouleursCoach.orangeClair,
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
                                  onPressed: () => widget.ouvrirLien(maj.page),
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
                      color: CouleursCoach.texteDoux,
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
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(t.confidentialite),
            onTap: () => widget.ouvrirLien(Uri.parse(lienConfidentialite)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t.boutonDeconnexion),
            subtitle: widget.utilisateur.prenom == null
                ? null
                : Text(widget.utilisateur.prenom!),
            onTap: _deconnecter,
          ),
        ],
      ),
    );
  }
}
