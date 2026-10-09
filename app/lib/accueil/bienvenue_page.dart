import 'package:flutter/material.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/questionnaire/etapes.dart';

class BienvenuePage extends StatefulWidget {
  const BienvenuePage({super.key, required this.auth, required this.onCommencer});

  final AuthService auth;
  final VoidCallback onCommencer;

  @override
  State<BienvenuePage> createState() => _BienvenuePageState();
}

class _BienvenuePageState extends State<BienvenuePage> {
  bool _enCours = false;
  bool _echec = false;

  Future<void> _connecter() async {
    setState(() {
      _enCours = true;
      _echec = false;
    });
    try {
      // Annulation : rien à faire. Succès : la racine bascule d'elle-même.
      await widget.auth.connecterGoogle();
    } on ConnexionEchouee {
      if (mounted) setState(() => _echec = true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.fitness_center,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(t.bienvenueTitre,
                  textAlign: TextAlign.center, style: textes.headlineMedium),
              const SizedBox(height: 12),
              Text(t.bienvenueSousTitre,
                  textAlign: TextAlign.center, style: textes.titleMedium),
              const Spacer(),
              if (_echec) ...[
                EncadreAlerte(t.erreurConnexion),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _enCours ? null : widget.onCommencer,
                child: Text(t.boutonCommencer),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _enCours ? null : _connecter,
                child: Text(t.boutonDejaCompte),
              ),
              const SizedBox(height: 16),
              Text(t.mentionMedicale,
                  textAlign: TextAlign.center, style: textes.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
