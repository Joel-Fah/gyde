// lib/utils/time.dart
import 'package:intl/intl.dart';

String formatFriendlyTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  final time = DateFormat.jm().format(dt); // e.g., 5:30 PM

  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return time; // today: show time only
  } else if (difference == 1) {
    return 'Yesterday · $time';
  } else if (difference < 7) {
    final weekday = DateFormat.E().format(dt); // Mon, Tue
    return '$weekday · $time';
  } else {
    final dateStr = DateFormat.MMMd().format(dt); // Sep 12
    return '$dateStr · $time';
  }
}

