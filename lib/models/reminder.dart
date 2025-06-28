import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String text;

  @HiveField(1)
  DateTime time;

  @HiveField(2)
  String? location; // Location name

  @HiveField(3)
  double? latitude;

  @HiveField(4)
  double? longitude;

  @HiveField(5)
  bool isLocationBased;

  @HiveField(6)
  String? triggerType; // 'ENTER' or 'EXIT'

  Reminder({
    required this.text,
    required this.time,
    this.location,
    this.latitude,
    this.longitude,
    this.isLocationBased = false,
    this.triggerType,
  });
}
