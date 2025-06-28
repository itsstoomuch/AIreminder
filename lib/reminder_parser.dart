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

/// Holds geofence info detected from text.
class GeofenceTrigger {
  final String locationName;
  final String triggerType; // 'ENTER' or 'EXIT'

  GeofenceTrigger({
    required this.locationName,
    required this.triggerType,
  });
}

/// Parses input text to detect geofence phrases like:
/// - "when I leave home"
/// - "when I go to station"
/// Returns null if none found.
GeofenceTrigger? parseGeofenceTrigger(String input) {
  final lower = input.toLowerCase();

  // Match "when I leave <place>"
  final leaveMatch = RegExp(r'when i leave (\w+)').firstMatch(lower);
  if (leaveMatch != null) {
    return GeofenceTrigger(
      locationName: leaveMatch.group(1)!,
      triggerType: 'EXIT',
    );
  }

  // Match "when I go to <place>", "when I reach <place>", "when I arrive at <place>"
  final arriveMatch = RegExp(
    r'when i (go to|reach|arrive at) (\w+)',
  ).firstMatch(lower);
  if (arriveMatch != null) {
    return GeofenceTrigger(
      locationName: arriveMatch.group(2)!,
      triggerType: 'ENTER',
    );
  }

  return null;
}

class ChronoParser {
  List<ParsedResult> parse(String input) {
    return Chrono.parse(input);
  }
}
