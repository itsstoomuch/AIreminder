import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models/reminder.dart';

class ReminderProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  List<Reminder> _reminders = [];

  ReminderProvider(this._notificationsPlugin);

  List<Reminder> get reminders => _reminders;

  static Future<ReminderProvider> init() async {
    final plugin = await initPlugin();
    final provider = ReminderProvider(plugin);
    await provider._loadReminders();
    return provider;
  }

  static Future<FlutterLocalNotificationsPlugin> initPlugin() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    await plugin.initialize(
      InitializationSettings(android: android, iOS: iOS),
    );
    tz.initializeTimeZones();
    return plugin;
  }

  Future<void> _loadReminders() async {
    final box = await Hive.openBox<Reminder>('remindersBox');
    _reminders = box.values.toList();
    notifyListeners();
  }

  Future<void> addReminder(Reminder reminder) async {
    _reminders.add(reminder);
    notifyListeners();

    final box = await Hive.openBox<Reminder>('remindersBox');
    await box.add(reminder);

    if (reminder.time.isAfter(DateTime.now())) {
      await _notificationsPlugin.zonedSchedule(
        reminder.hashCode,
        'Reminder',
        reminder.text,
        tz.TZDateTime.from(reminder.time, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails('reminder_channel', 'Reminders',
              importance: Importance.max),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> removeReminder(int index) async {
    final box = await Hive.openBox<Reminder>('remindersBox');
    final reminder = _reminders.removeAt(index);
    await box.deleteAt(index);
    notifyListeners();
    await _notificationsPlugin.cancel(reminder.hashCode);
  }
}
