import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

/// Lit un code-barres avec la caméra ; renvoie le code ou null.
/// Un champ permet aussi de le taper si la caméra n'est pas disponible.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _code = TextEditingController();
  bool _termine = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _rendre(String? code) {
    if (_termine || code == null || code.trim().isEmpty) return;
    _termine = true;
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.scanTitre)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) =>
                  _rendre(capture.barcodes.firstOrNull?.rawValue),
              errorBuilder: (context, error) => Center(child: Text(t.scanAide)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.scanAide, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t.champCode,
                    helperText: t.scanOuSaisir,
                  ),
                  onSubmitted: _rendre,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _rendre(_code.text),
                  child: Text(t.scanRechercher),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
