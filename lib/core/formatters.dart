import 'package:intl/intl.dart';

/// Formatações de texto usadas em todo o app.
class Format {
  static final NumberFormat _weight = NumberFormat('#,##0.##', 'pt_BR');
  static final NumberFormat _integer = NumberFormat('#,##0', 'pt_BR');
  static final DateFormat _shortDate = DateFormat("d 'de' MMM", 'pt_BR');
  static final DateFormat _fullDate = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');

  static String kg(num value) => '${_weight.format(value)} kg';

  static String weight(num value) => _weight.format(value);

  static String number(num value) => _integer.format(value);

  /// Volume grande vira tonelada para caber no card.
  static String volume(num kilos) {
    if (kilos >= 1000) {
      return '${_weight.format(kilos / 1000)} t';
    }
    return kg(kilos);
  }

  static String date(DateTime? value) =>
      value == null ? '' : _shortDate.format(value);

  static String fullDate(DateTime? value) =>
      value == null ? '' : _fullDate.format(value);

  /// "agora", "há 5 min", "há 3 h", "há 2 d" ou a data.
  static String timeAgo(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value);

    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays < 7) return 'há ${diff.inDays} d';
    return _shortDate.format(value);
  }

  /// Cronômetro da sessão: "42 min" ou "1h 12min".
  static String duration(Duration value) {
    final minutes = value.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
  }

  static String plural(int count, String singular, String plural) =>
      count == 1 ? '$count $singular' : '$count $plural';
}
