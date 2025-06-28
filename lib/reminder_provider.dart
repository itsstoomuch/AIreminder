import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geofence_service/models/geofence.dart';
import 'package:geofence_service/models/geofence_radius.dart';
import 'package:geofence_service/models/geofence_status.dart';

import 'models/reminder.dart';
import 'models/saved_location.dart';

class ReminderProvider extends ChangeNotifier {
  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
  );

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => _reminders;

  static Future<ReminderProvider> init() async {
    await Hive.openBox<Reminder>('reminders');
    await Hive.openBox<SavedLocation>('saved_locations');

    final provider = ReminderProvider();
    provider._reminders = Hive.box<Reminder>('reminders').values.toList();
    provider._setupGeofenceEventHandler();
    return provider; // ✅ always returns
  }

  void _setupGeofenceEventHandler() {
    _geofenceService.addGeofenceStatusChangeListener(
      (Geofence geofence, GeofenceRadius radius, GeofenceStatus status,
          Location location) {
        debugPrint(
          'Geofence triggered: ${geofence.id} | Status: ${status.toString()} at ${location.latitude}, ${location.longitude}',
        );
        return Future.value(); // If the listener expects Future<void>
      },
    );
  }

  Future<void> addReminder(Reminder reminder) async {
    final box = Hive.box<Reminder>('reminders');
    await box.add(reminder);
    _reminders.add(reminder);
    notifyListeners();

    if (reminder.isLocationBased &&
        reminder.latitude != null &&
        reminder.longitude != null) {
      final geofence = Geofence(
        id: 'reminder_${reminder.key}',
        latitude: reminder.latitude!,
        longitude: reminder.longitude!,
        radius: [GeofenceRadius(id: 'radius_100', length: 100)],
      );
      _geofenceService.addGeofence(geofence);
    }
    return Future.value(); // ✅ always returns Future<void>
  }

  Future<void> removeReminder(int index) async {
    final reminder = _reminders[index];

    if (reminder.isLocationBased) {
      _geofenceService.removeGeofenceById('reminder_${reminder.key}');
    }

    await Hive.box<Reminder>('reminders').delete(reminder.key);
    _reminders.removeAt(index);
    notifyListeners();
    return Future.value(); // ✅ always returns Future<void>
  }

  Future<void> _initializeGeofences() async {
    for (final reminder in _reminders) {
      if (reminder.isLocationBased &&
          reminder.latitude != null &&
          reminder.longitude != null) {
        final geofence = Geofence(
          id: 'reminder_${reminder.key}',
          latitude: reminder.latitude!,
          longitude: reminder.longitude!,
          radius: [GeofenceRadius(id: 'radius_100', length: 100)],
        );
        _geofenceService.addGeofence(geofence);
      }
    }
    return Future.value(); // ✅ always returns Future<void>
  }

  List<String> getSavedLocationNames() {
    final box = Hive.box<SavedLocation>('saved_locations');
    return box.values.map((loc) => loc.name.toLowerCase()).toList();
  }

  SavedLocation? getLocationByName(String name) {
    final box = Hive.box<SavedLocation>('saved_locations');
    try {
      return box.values.firstWhere(
        (loc) => loc.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
