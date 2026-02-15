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
    const seed = Color(0xFF7C5CFF);
    final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reminder AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF090B16),
        cardTheme: const CardTheme(
          color: Color(0xFF15182B),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
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
        _selectedLocation = 'Current location';
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

    if (!mounted) return;
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
    final diff = time.difference(DateTime.now());
    if (diff.isNegative) return 'Past due';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min left';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    return '${diff.inDays} day(s) left';
  }

  Widget _buildComposerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create reminder',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _parseAndAutoLinkLocation,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Remind me to submit report tomorrow at 8am',
                prefixIcon: const Icon(Icons.auto_awesome),
                filled: true,
                fillColor: const Color(0xFF1C2138),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Time'), icon: Icon(Icons.schedule)),
                ButtonSegment<bool>(value: true, label: Text('Location'), icon: Icon(Icons.location_on)),
              ],
              selected: {isLocationBased},
              onSelectionChanged: (value) => setState(() => isLocationBased = value.first),
            ),
            const SizedBox(height: 14),
            if (!isLocationBased) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF1C2138),
                ),
                child: SizedBox(
                  height: 120,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    onDateTimeChanged: (val) => setState(() => _selectedTime = TimeOfDay.fromDateTime(val)),
                    initialDateTime: DateTime.now(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_selectedDate)),
              ),
            ] else ...[
              SizedBox(
                height: 185,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Current'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
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
                      label: const Text('Pick on map'),
                    ),
                  ),
                ],
              ),
              if (_selectedLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Selected: $_selectedLocation'),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.alarm_add),
              label: const Text('Save reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder item, int index) {
    return Dismissible(
      key: Key(item.key.toString()),
      onDismissed: (_) => context.read<ReminderProvider>().removeReminder(index),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.red.shade400,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF171D34), Color(0xFF111527)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: item.isLocationBased ? Colors.purple.withOpacity(0.2) : Colors.cyan.withOpacity(0.2),
            child: Icon(item.isLocationBased ? Icons.location_on : Icons.schedule),
          ),
          title: Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: item.isLocationBased && item.latitude != null && item.longitude != null
              ? FutureBuilder<double>(
                  future: _calculateDistance(item.latitude, item.longitude),
                  builder: (context, snapshot) {
                    final km = (snapshot.data ?? 0) / 1000;
                    return Text('${item.location ?? 'Unnamed location'} • ${km.toStringAsFixed(2)} km away');
                  },
                )
              : Text('${DateFormat('EEE, d MMM • hh:mm a').format(item.time)} • ${_getCountdown(item.time)}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderProvider>().reminders;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111327), Color(0xFF070914)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Color(0xFF724BFF), Color(0xFF3E9BFF)]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF724BFF).withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reminder AI', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Plan tasks by time or location • ${reminders.length} active'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildComposerCard(),
              const SizedBox(height: 16),
              Text('Upcoming reminders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (reminders.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: const [
                        Icon(Icons.inbox_outlined, size: 40),
                        SizedBox(height: 10),
                        Text('No reminders yet. Create one from the card above.'),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(reminders.length, (index) => _buildReminderCard(reminders[index], index)),
            ],
          ),
        ),
      ),
    );
  }
}
