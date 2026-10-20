import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compte/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../profil/questionnaire/etapes.dart';
import '../theme.dart';

class BienvenuePage extends StatefulWidget {
  const BienvenuePage({
    super.key,
    required this.auth,
    required this.onCommencer,
  });

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Bandeau(
                titre: t.bienvenueTitre,
                sousTitre: t.bienvenueSousTitre,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Promesse(t.bienvenuePoint1),
                    const SizedBox(height: 10),
                    _Promesse(t.bienvenuePoint2),
                    const SizedBox(height: 28),
                    if (_echec) ...[
                      EncadreAlerte(t.erreurConnexion),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _enCours ? null : widget.onCommencer,
                      child: Text(t.boutonCommencer),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _enCours ? null : _connecter,
                      child: Text(t.boutonDejaCompte),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.mentionMedicale,
                      textAlign: TextAlign.center,
                      style: textes.bodySmall?.copyWith(
                        color: context.palette.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.titre, required this.sousTitre});

  final String titre;
  final String sousTitre;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: CouleursCoach.vert,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Pastille(
                    Icons.fitness_center,
                    CouleursCoach.vertMoyen,
                    Colors.white,
                  ),
                  SizedBox(width: 14),
                  _Pastille(
                    Icons.restaurant,
                    CouleursCoach.orange,
                    CouleursCoach.orangeFonce,
                  ),
                  SizedBox(width: 14),
                  _Pastille(
                    Icons.directions_run,
                    CouleursCoach.vertMoyen,
                    Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: textes.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                sousTitre,
                textAlign: TextAlign.center,
                style: textes.titleMedium?.copyWith(
                  color: CouleursCoach.vertPale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.icone, this.fond, this.couleur);

  final IconData icone;
  final Color fond;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
    child: Icon(icone, color: couleur, size: 30),
  );
}

class _Promesse extends StatelessWidget {
  const _Promesse(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
        size: 22,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          texte,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: context.palette.texteDoux),
        ),
      ),
    ],
  );
}
