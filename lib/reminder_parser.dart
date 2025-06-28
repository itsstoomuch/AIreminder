import 'package:chrono_dart/chrono_dart.dart';

DateTime? parseDateTime(String input) {
  final chrono = ChronoParser();
  final results = chrono.parse(input);
  if (results.isNotEmpty) {
    return results.first.date();
  }
  return null;
}

/// Returns the name of a saved location found in the text, or null.
String? extractLocationName(String input, List<String> savedLocations) {
  for (final loc in savedLocations) {
    final regex =
        RegExp(r'\b' + RegExp.escape(loc) + r'\b', caseSensitive: false);
    if (regex.hasMatch(input)) {
      return loc;
    }
  }
  return null;
}

class ChronoParser {
  List<ParsedResult> parse(String input) {
    return Chrono.parse(input);
  }
}
