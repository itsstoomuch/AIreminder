import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  late String text;

  @HiveField(1)
  late DateTime time;

  Reminder({required this.text, required this.time});
}
