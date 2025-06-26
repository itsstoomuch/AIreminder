import 'package:chrono_dart/chrono_dart.dart';

class ParsedReminder {
  final String text;
  final DateTime dateTime;

  ParsedReminder(this.text, this.dateTime);
}

ParsedReminder? parseReminder(String input) {
  final results = Chrono.parse(input);
  if (results.isNotEmpty) {
    final parsedDate = results.first.date();
    return ParsedReminder(input, parsedDate);
  }
  return null;
}
