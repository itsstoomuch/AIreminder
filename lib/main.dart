import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'map_picker_preview.dart';
import 'map_picker_screen.dart';
import 'models/reminder.dart';
import 'models/saved_location.dart';
import 'reminder_parser.dart';
import 'reminder_provider.dart';

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
    const seed = Color(0xFF6C63FF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reminder AI',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _parseAndAutoLinkLocation(String input) {
    final provider = context.read<ReminderProvider>();
    final parsedDateTime = parseDateTime(input);

    if (parsedDateTime != null) {
      setState(() {
        _selectedDate = parsedDateTime;
        _selectedTime = TimeOfDay.fromDateTime(parsedDateTime);
      });
    }

    for (final name in provider.getSavedLocationNames()) {
      if (input.toLowerCase().contains(name)) {
        final match = provider.getLocationByName(name);
        if (match != null) {
          setState(() {
            _selectedLocation = match.name;
            _selectedLat = match.latitude;
            _selectedLng = match.longitude;
          });
          break;
        }
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _selectedLat = pos.latitude;
        _selectedLng = pos.longitude;
        _selectedLocation = 'Current Location';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch current location.')),
      );
    }
  }

  Future<void> _addReminder() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder first.')),
      );
      return;
    }

    final provider = context.read<ReminderProvider>();
    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final geofence = parseGeofenceTrigger(text);
    String? locationName = _selectedLocation;
    double? lat = _selectedLat;
    double? lng = _selectedLng;
    String? triggerType;

    var locationMode = isLocationBased;

    if (geofence != null) {
      locationMode = true;
      triggerType = geofence.triggerType;

      final matched = provider.getLocationByName(geofence.locationName);
      if (matched != null) {
        locationName = matched.name;
        lat = matched.latitude;
        lng = matched.longitude;
      } else {
        final picked = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapPickerScreen()),
        );
        if (picked != null && picked is Map) {
          lat = picked['position']?.latitude;
          lng = picked['position']?.longitude;
          locationName = picked['name'];
        }
      }
    }

    if (locationMode && (locationName == null || lat == null || lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid location.')),
      );
      return;
    }

    if (!locationMode && combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future date and time.')),
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
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _selectedLocation = null;
      _selectedLat = null;
      _selectedLng = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder added successfully.')),
    );
  }

  Future<double> _calculateDistance(double? lat, double? lng) async {
    if (lat == null || lng == null) return 0;
    final pos = await Geolocator.getCurrentPosition();
    return Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
  }

  String _getCountdown(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) return 'Past due';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min left';
    if (diff.inHours < 24) return '${diff.inHours} hr ${diff.inMinutes % 60} min left';
    return '${diff.inDays} day(s) left';
  }

  Widget _buildReminderCard(Reminder item, int index) {
    return Dismissible(
      key: Key(item.key.toString()),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => context.read<ReminderProvider>().removeReminder(index),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(item.text),
          subtitle: item.isLocationBased && item.latitude != null && item.longitude != null
              ? FutureBuilder<double>(
                  future: _calculateDistance(item.latitude, item.longitude),
                  builder: (context, snapshot) {
                    final distanceKm = (snapshot.data ?? 0) / 1000;
                    return Text(
                      '${item.location ?? 'Unnamed location'} • ${distanceKm.toStringAsFixed(2)} km away',
                    );
                  },
                )
              : Text(
                  '${DateFormat('EEE, d MMM • hh:mm a').format(item.time)} • ${_getCountdown(item.time)}',
                ),
          leading: Icon(item.isLocationBased ? Icons.location_on : Icons.schedule),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderProvider>().reminders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder AI'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Smart reminders that understand time and place.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CupertinoTextField(
                      controller: _controller,
                      placeholder: 'e.g. Remind me to call mom tomorrow at 8pm',
                      padding: const EdgeInsets.all(14),
                      onChanged: _parseAndAutoLinkLocation,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Time Based'),
                          selected: !isLocationBased,
                          onSelected: (_) => setState(() => isLocationBased = false),
                        ),
                        ChoiceChip(
                          label: const Text('Location Based'),
                          selected: isLocationBased,
                          onSelected: (_) => setState(() => isLocationBased = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isLocationBased) ...[
                      SizedBox(
                        height: 120,
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: DateTime.now(),
                          onDateTimeChanged: (val) {
                            setState(() => _selectedTime = TimeOfDay.fromDateTime(val));
                          },
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('EEE, d MMM yyyy').format(_selectedDate)),
                      ),
                    ] else ...[
                      SizedBox(
                        height: 170,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _useCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Use current location'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                              );
                              if (picked != null && picked is Map) {
                                setState(() {
                                  _selectedLat = picked['position']?.latitude;
                                  _selectedLng = picked['position']?.longitude;
                                  _selectedLocation = picked['name'];
                                });
                              }
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Choose on map'),
                          ),
                        ],
                      ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 8),
                        Text('Selected: $_selectedLocation'),
                      ],
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _addReminder,
                      icon: const Icon(Icons.add_alarm),
                      label: const Text('Add Reminder'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Your reminders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (reminders.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: const [
                      Icon(Icons.notifications_none, size: 36),
                      SizedBox(height: 8),
                      Text('No reminders yet. Add your first reminder above.'),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(reminders.length, (index) {
                final item = reminders[index];
                return _buildReminderCard(item, index);
              }),
          ],
        ),
      ),
    );
  }
}
