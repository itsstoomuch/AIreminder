import 'package:hive/hive.dart';

part 'saved_location.g.dart';

@HiveType(
    typeId: 1) // Make sure this is different from Reminder (which is typeId: 0)
class SavedLocation extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double latitude;

  @HiveField(2)
  double longitude;

  SavedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
