// lib/main.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'reminder_provider.dart';
import 'models/reminder.dart';
import 'models/saved_location.dart';
import 'map_picker_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  void _addReminder() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = Reminder(
      text: text,
      time: combined,
      location: _selectedLocation,
      latitude: _selectedLat,
      longitude: _selectedLng,
      isLocationBased: isLocationBased,
    );

    context.read<ReminderProvider>().addReminder(reminder);
    _controller.clear();
    setState(() {
      _selectedLocation = null;
      _selectedLat = null;
      _selectedLng = null;
      isLocationBased = false;
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
              ? '📍 ${item.location ?? "Unknown"}\n🧭 ${(distance / 1000).toStringAsFixed(2)} km away'
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
                  child: _selectedLat != null && _selectedLng != null
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_selectedLat!, _selectedLng!),
                            zoom: 14,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('selectedLocation'),
                              position: LatLng(_selectedLat!, _selectedLng!),
                            ),
                          },
                          zoomGesturesEnabled: false,
                          scrollGesturesEnabled: false,
                        )
                      : Center(
                          child: Text('No location selected',
                              style: TextStyle(color: Colors.white70)),
                        ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.location_on),
                  label: Text(_selectedLocation ?? 'Pick Location'),
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
