import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Date/time formatting utilities
class DateFormatter {
  DateFormatter._();

  /// Full date: 8 Mei 2026
  static String formatDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  /// Short date: 08/05/2026
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Date with time: 8 Mei 2026, 14:30
  static String formatDateTime(DateTime date) {
    return DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(date);
  }

  /// Time only: 14:30
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Relative time: 5 menit yang lalu
  static String formatRelative(DateTime date) {
    return timeago.format(date, locale: 'id');
  }

  /// Chat timestamp: Today 14:30 / Yesterday / 8 Mei
  static String formatChatTimestamp(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Hari ini ${formatTime(date)}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Kemarin ${formatTime(date)}';
    } else {
      return DateFormat('d MMM, HH:mm', 'id_ID').format(date);
    }
  }
}
