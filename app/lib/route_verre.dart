import 'package:flutter/material.dart';

import 'verre.dart';

/// Route d'un écran ouvert par-dessus les onglets (Réglages, Idées...) : la
/// page est posée sur son propre fond de verre, et son Scaffold est rendu
/// transparent pour laisser voir les taches de couleur, comme les onglets.
///
/// Le fond est porté par la route et non par `MaterialApp.builder` : il est
/// opaque, si bien que pendant une transition la page précédente ne se voit
/// jamais à travers la nouvelle (deux pages transparentes superposées).
Route<T> routeVerre<T>(WidgetBuilder builder, {RouteSettings? settings}) =>
    MaterialPageRoute<T>(
      settings: settings,
      builder: (context) => FondVerre(
        child: Theme(
          data: Theme.of(context)
              .copyWith(scaffoldBackgroundColor: Colors.transparent),
          // Le contexte passé à la page est sous le thème transparent.
          child: ColonneCentree(child: Builder(builder: builder)),
        ),
      ),
    );
