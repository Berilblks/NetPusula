class CalendarDate {
  const CalendarDate(this.year, this.month, this.day);
  final int year, month, day;
  factory CalendarDate.local(DateTime now) =>
      CalendarDate(now.year, now.month, now.day);
  factory CalendarDate.parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Invalid date');
    }
    final date = DateTime.parse(text);
    final result = CalendarDate.local(date);
    if (result.iso != text) throw const FormatException('Invalid date');
    return result;
  }
  DateTime get pickerDate => DateTime(year, month, day);
  DateTime get _utc => DateTime.utc(year, month, day);
  String get iso =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  int compareTo(CalendarDate other) => _utc.compareTo(other._utc);
  int daysRemaining(CalendarDate today) =>
      _utc.difference(today._utc).inDays.clamp(0, 3652059);
}

// Decimal net values are kept as scaled integers; no floating-point comparison or accumulation.
class NetTarget {
  const NetTarget._(this.units);
  final int units;
  static NetTarget? parse(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,8}(?:\.\d{1,4})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final units =
        int.parse(parts[0]) * 10000 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(4, '0'));
    return units > 0 && units <= 999999999999 ? NetTarget._(units) : null;
  }

  factory NetTarget.fromJson(Object? value) {
    if (value is! num) throw const FormatException('Invalid target');
    return parse(value.toString()) ??
        (throw const FormatException('Invalid target'));
  }
  String get decimal {
    final fraction = (units % 10000)
        .toString()
        .padLeft(4, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${units ~/ 10000}${fraction.isEmpty ? '' : '.$fraction'}';
  }

  String get turkish => decimal.replaceAll('.', ',');
  num get jsonNumber => num.parse(decimal);
}

class PreparationExam {
  const PreparationExam({
    required this.id,
    required this.code,
    required this.name,
    this.maximum,
  });
  final String id, code, name;
  final NetTarget? maximum;
  factory PreparationExam.fromJson(Map<String, dynamic> json) =>
      PreparationExam(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        maximum:
            json['maximumTargetNet'] == null
                ? null
                : NetTarget.fromJson(json['maximumTargetNet']),
      );
}

class Preparation {
  const Preparation({
    required this.id,
    required this.exam,
    required this.target,
    required this.date,
  });
  final String id;
  final PreparationExam exam;
  final NetTarget target;
  final CalendarDate date;
  factory Preparation.fromJson(Map<String, dynamic> json) => Preparation(
    id: json['id'] as String,
    exam: PreparationExam.fromJson(json['exam'] as Map<String, dynamic>),
    target: NetTarget.fromJson(json['targetNet']),
    date: CalendarDate.parse(json['examDate'] as String),
  );
}
