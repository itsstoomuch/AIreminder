import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'reminder_provider.dart';
import 'models/reminder.dart';
import 'models/saved_location.dart';
import 'map_picker_preview.dart';
import 'map_picker_screen.dart';
import 'reminder_parser.dart';
import 'notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(SavedLocationAdapter());
  final provider = await ReminderProvider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ReminderScreen(),
    );
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final TextEditingController _controller = TextEditingController();
  bool isLocationBased = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedLocation;
  double? _selectedLat;
  double? _selectedLng;

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _parseAndAutoLinkLocation(String input) {
    final provider = context.read<ReminderProvider>();
    for (final name in provider.getSavedLocationNames()) {
      if (input.toLowerCase().contains(name)) {
        final match = provider.getLocationByName(name);
        if (match != null) {
          setState(() {
            _selectedLocation = match.name;
            _selectedLat = match.latitude;
            _selectedLng = match.longitude;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text("Linked saved location '${match.name}' automatically."),
              duration: const Duration(seconds: 2),
            ),
          );
          break;
        }
      }
    }
  }

  void _useCurrentLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _selectedLat = pos.latitude;
      _selectedLng = pos.longitude;
      _selectedLocation = "Current Location";
    });
  }

  void _addReminder() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ReminderProvider>();

    // 1️⃣ Combine date + time (fallback for time-based)
    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // 2️⃣ Try geofence parsing
    final geofence = parseGeofenceTrigger(text);

    String? locationName = _selectedLocation;
    double? lat = _selectedLat;
    double? lng = _selectedLng;
    String? triggerType;

    bool locationMode = isLocationBased;

    if (geofence != null) {
      locationMode = true; // force location-based
      triggerType = geofence.triggerType;

      // Try find saved pin
      final matched = provider.getLocationByName(geofence.locationName);
      if (matched != null) {
        locationName = matched.name;
        lat = matched.latitude;
        lng = matched.longitude;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Linked '${matched.name}' for geofence (${triggerType ?? ''})"),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Not found → open map picker
        final picked = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapPickerScreen()),
        );
        if (picked != null && picked is Map) {
          lat = picked['position']?.latitude;
          lng = picked['position']?.longitude;
          locationName = picked['name'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No location selected. Reminder not saved.'),
            ),
          );
          return;
        }
      }
    }

    if (locationMode && (locationName == null || lat == null || lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a valid location.'),
            duration: Duration(seconds: 2)),
      );
      return;
    }

    final reminder = Reminder(
      text: text,
      time: combined,
      location: locationName,
      latitude: lat,
      longitude: lng,
      isLocationBased: locationMode,
      triggerType: triggerType,
    );

    await provider.addReminder(reminder);

    _controller.clear();
    setState(() {
      if (!locationMode) {
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      }
      _selectedLocation = null;
      _selectedLat = null;
      _selectedLng = null;
    });
  }

  Future<double> _calculateDistance(double? lat, double? lng) async {
    if (lat == null || lng == null) return 0;
    final pos = await Geolocator.getCurrentPosition();
    return Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
  }

  Widget _getReminderInfo(Reminder item) {
    if (item.isLocationBased &&
        item.latitude != null &&
        item.longitude != null) {
      return FutureBuilder<double>(
        future: _calculateDistance(item.latitude, item.longitude),
        builder: (context, snapshot) {
          final distance = snapshot.data;
          final info = distance != null
              ? '📍 ${item.location ?? "Unnamed Location"}\n🧭 ${(distance / 1000).toStringAsFixed(2)} km away'
              : '📍 ${item.location ?? "Loading..."}';
          return Text(info, style: const TextStyle(color: Colors.white70));
        },
      );
    } else {
      final countdown = _getCountdown(item.time);
      return Text(
        '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')} on ${item.time.day}/${item.time.month}/${item.time.year}\n$countdown',
        style: const TextStyle(color: Colors.white70),
      );
    }
  }

  String _getCountdown(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) return '⏰ Past due';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min left';
    if (diff.inHours < 24)
      return '${diff.inHours} hr ${diff.inMinutes % 60} min left';
    return '${diff.inDays} day(s) left';
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderProvider>().reminders;

    return Scaffold(
      appBar: AppBar(title: const Text("Reminder AI"), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _controller,
                placeholder: 'Type or speak your reminder...',
                style: const TextStyle(color: Colors.white),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                onChanged: (val) => _parseAndAutoLinkLocation(val),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("Time Based"),
                    selected: !isLocationBased,
                    onSelected: (_) => setState(() => isLocationBased = false),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Location Based"),
                    selected: isLocationBased,
                    onSelected: (_) => setState(() => isLocationBased = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isLocationBased) ...[
                SizedBox(
                  height: 150,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime.now(),
                    onDateTimeChanged: (val) => setState(
                        () => _selectedTime = TimeOfDay.fromDateTime(val)),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                ),
              ] else ...[
                SizedBox(
                  height: 150,
                  child: MapPickerPreview(
                    onLocationSelected: (position, name) {
                      setState(() {
                        _selectedLat = position.latitude;
                        _selectedLng = position.longitude;
                        _selectedLocation = name;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _useCurrentLocation,
                      icon:
                          const Icon(Icons.my_location, color: Colors.white70),
                      label: const Text("Use Current Location",
                          style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MapPickerScreen()),
                        );
                        if (picked != null && picked is Map) {
                          setState(() {
                            _selectedLat = picked['position']?.latitude;
                            _selectedLng = picked['position']?.longitude;
                            _selectedLocation = picked['name'];
                          });
                        }
                      },
                      icon: const Icon(Icons.map, color: Colors.white70),
                      label: const Text("Open Full Map",
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _addReminder,
                icon: const Icon(Icons.alarm),
                label: const Text('Add Reminder'),
              ),
              const Divider(height: 30),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final item = reminders[index];
                  return Dismissible(
                    key: Key(item.key.toString()),
                    background: Container(color: Colors.red),
                    onDismissed: (_) =>
                        context.read<ReminderProvider>().removeReminder(index),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(item.text,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: _getReminderInfo(item),
                        leading: item.isLocationBased
                            ? const Icon(Icons.location_on,
                                color: Colors.purpleAccent)
                            : const Icon(Icons.access_time, color: Colors.cyan),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
