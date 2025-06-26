import 'package:chrono_dart/chrono_dart.dart';

DateTime? parseDateTime(String input) {
  final chrono = ChronoParser();
  final results = chrono.parse(input); // returns List<ParsedResult>

  if (results.isNotEmpty) {
    return results.first.date(); // DateTime object
  }

  return null;
}

class ChronoParser {
  List<ParsedResult> parse(String input) {
    return Chrono.parse(input);
  }
}
