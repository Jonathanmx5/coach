/// Noms lisibles des applications qui écrivent dans Health Connect. Une source
/// inconnue est affichée par son identifiant de paquet abrégé.
const _noms = {
  'com.google.android.apps.fitness': 'Google Fit',
  'com.xiaomi.wearable': 'Mi Fitness',
  'com.mi.health': 'Mi Fitness',
  'com.xiaomi.hm.health': 'Zepp Life',
  'com.huami.watch.hmwatchmanager': 'Zepp',
  'com.samsung.android.shealth': 'Samsung Health',
  'com.sec.android.app.shealth': 'Samsung Health',
  'com.garmin.android.apps.connectmobile': 'Garmin Connect',
  'com.fitbit.FitbitMobile': 'Fitbit',
  'com.huawei.health': 'Huawei Santé',
  'com.oppo.health': 'HeyTap Santé',
  'com.polar.polarflow': 'Polar Flow',
  'com.strava': 'Strava',
  'com.google.android.apps.healthdata': 'Health Connect',
  'com.android.healthconnect.phone': 'Téléphone',
};

/// « com.google.android.apps.fitness » devient « Google Fit ».
String nomDeSource(String? source) {
  final s = (source ?? '').trim();
  if (s.isEmpty) return '';
  final connu = _noms[s];
  if (connu != null) return connu;
  // Health Connect ajoute parfois un suffixe aléatoire au paquet du téléphone.
  for (final e in _noms.entries) {
    if (s.startsWith('${e.key}.')) return e.value;
  }
  final morceaux = s.split('.');
  return morceaux.isEmpty ? s : morceaux.last;
}
