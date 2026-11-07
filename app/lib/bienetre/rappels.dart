import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'complements.dart';

/// Rappels quotidiens des compléments.
abstract class Rappels {
  /// Demande l'autorisation d'afficher des notifications.
  Future<bool> autoriser();

  /// Remplace tous les rappels par ceux des compléments actifs.
  Future<void> planifier(List<Complement> complements);
}

class RappelsLocaux implements Rappels {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _pret;

  Future<void> _init() => _pret ??= () async {
    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }();

  @override
  Future<bool> autoriser() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> planifier(List<Complement> complements) async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
      final maintenant = tz.TZDateTime.now(tz.local);
      for (final c in complements) {
        if (!c.actif || c.id == null) continue;
        var quand = tz.TZDateTime(
          tz.local,
          maintenant.year,
          maintenant.month,
          maintenant.day,
          c.minutes ~/ 60,
          c.minutes % 60,
        );
        if (!quand.isAfter(maintenant)) {
          quand = quand.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id: c.id.hashCode & 0x7fffffff,
          title: 'Complément',
          body: c.nom,
          scheduledDate: quand,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'complements',
              'Compléments',
              channelDescription: 'Rappels quotidiens des compléments',
            ),
          ),
          // Heure approximative : pas besoin de l'autorisation d'alarme exacte.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {
      // Pas de rappel possible : la liste des compléments reste utilisable.
    }
  }
}
