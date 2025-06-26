import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminderai/reminder_provider.dart';
import 'package:reminderai/models/reminder.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());
  final provider = await ReminderProvider.init();
  runApp(ChangeNotifierProvider.value(
    value: provider,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.purpleAccent,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
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
  final TextEditingController _aiController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addReminder() {
    final text = _aiController.text.trim();
    if (text.isEmpty) return;
    final combined = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final reminder = Reminder(text: text, time: combined);
    Provider.of<ReminderProvider>(context, listen: false).addReminder(reminder);
    _aiController.clear();
  }

  String _buildCountdown(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) return "⏰ Time passed";

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;

    return "⏳ In ${days}d ${hours}h ${mins}m";
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderProvider>().reminders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder AI'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("⏰ Select Time", style: TextStyle(fontSize: 16)),
            SizedBox(
              height: 150,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime.now(),
                onDateTimeChanged: (val) => setState(() {
                  _selectedTime = TimeOfDay.fromDateTime(val);
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, color: Colors.white70),
              label: Text(
                DateFormat('dd MMMM yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _aiController,
              placeholder: 'Type or speak your reminder...',
              style: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addReminder,
              child: const Text('Add Reminder'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final item = reminders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(item.text,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${DateFormat('hh:mm a').format(item.time)} on ${DateFormat('dd MMM yyyy').format(item.time)}\n${_buildCountdown(item.time)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => Provider.of<ReminderProvider>(context,
                                listen: false)
                            .removeReminder(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.grey),
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.white54),
                  SizedBox(width: 8),
                  Text(
                    "AI Assistant Coming Soon...",
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
