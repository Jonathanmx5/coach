import 'dart:async';

import 'package:flutter/widgets.dart';

import 'donnees_widget.dart';

/// Tient le widget de l'écran d'accueil à jour sans le solliciter à chaque
/// reconstruction de l'Accueil : les chiffres proposés sont gardés, puis
/// envoyés [delai] après le premier changement, ou tout de suite quand
/// l'application passe en arrière-plan (c'est alors que l'écran d'accueil
/// redevient visible). Rien n'est envoyé si les chiffres n'ont pas changé.
class SynchroWidget with WidgetsBindingObserver {
  SynchroWidget(this._maj, {this.delai = const Duration(seconds: 3)}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final MiseAJourWidget _maj;
  final Duration delai;

  _Envoi? _envoye;
  _Envoi? _enAttente;
  Timer? _minuteur;
  bool _ferme = false;

  /// Propose les chiffres de [jour] pour le compte [uid]. Les calories
  /// brûlées sont arrondies à 10 kcal : sans montre, l'estimation monte
  /// d'environ 1 kcal par minute.
  void proposer(
    DonneesWidget donnees, {
    required DateTime jour,
    required String uid,
  }) {
    if (_ferme) return;
    final envoi = _Envoi(
      DonneesWidget(
        brulees: (donnees.brulees / 10).round() * 10.0,
        objectifBrule: donnees.objectifBrule,
        mangees: donnees.mangees,
        objectifMange: donnees.objectifMange,
        proteines: donnees.proteines,
        objectifProteines: donnees.objectifProteines,
        eauMl: donnees.eauMl,
        objectifEauMl: donnees.objectifEauMl,
        description: donnees.description,
      ),
      DateTime(jour.year, jour.month, jour.day),
      uid,
    );
    if (envoi == _envoye) {
      // Revenu aux chiffres déjà affichés : plus rien à envoyer.
      _enAttente = null;
      _minuteur?.cancel();
      _minuteur = null;
      return;
    }
    _enAttente = envoi;
    // Le délai court depuis le premier changement : une suite de changements
    // rapprochés ne repousse pas l'envoi indéfiniment.
    _minuteur ??= Timer(delai, envoyer);
  }

  /// Envoie tout de suite les chiffres en attente, s'il y en a.
  void envoyer() {
    _minuteur?.cancel();
    _minuteur = null;
    final envoi = _enAttente;
    if (envoi == null || _ferme) return;
    _enAttente = null;
    _envoye = envoi;
    unawaited(_maj.mettre(envoi.donnees, jour: envoi.jour, uid: envoi.uid));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      envoyer();
    }
  }

  /// Arrête la synchronisation sans rien envoyer : l'Accueil disparaît (autre
  /// jour, déconnexion), et ses chiffres ne doivent plus réécrire le widget.
  void fermer() {
    _ferme = true;
    _minuteur?.cancel();
    _minuteur = null;
    _enAttente = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}

@immutable
class _Envoi {
  const _Envoi(this.donnees, this.jour, this.uid);

  final DonneesWidget donnees;
  final DateTime jour;
  final String uid;

  @override
  bool operator ==(Object other) =>
      other is _Envoi &&
      other.donnees == donnees &&
      other.jour == jour &&
      other.uid == uid;

  @override
  int get hashCode => Object.hash(donnees, jour, uid);
}
