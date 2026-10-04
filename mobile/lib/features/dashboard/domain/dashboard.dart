import '../../preparation/domain/preparation.dart';
import '../../mock_exams/domain/mock_exam.dart';

class Score {
  Score(this.value) {
    if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) {
      throw const FormatException('Invalid score');
    }
  }
  final String value;
  String get display => displayNet(value);
  bool get isZero => !RegExp(r'[1-9]').hasMatch(value);
  bool get negative => value.startsWith('-') && !isZero;
  String get absolute => display.replaceFirst('-', '');
  double get chartValue =>
      double.parse(value); // Pixel geometry only; never a business metric.
}

Score? score(Object? v) => v == null ? null : Score(v as String);

class TrendPoint {
  TrendPoint(this.id, this.name, this.date, this.net);
  final String id, name;
  final CalendarDate date;
  final Score net;
  factory TrendPoint.json(Map<String, dynamic> j) => TrendPoint(
    j['mockExamId'] as String,
    j['name'] as String,
    CalendarDate.parse(j['takenAt'] as String),
    Score(j['totalNet'] as String),
  );
}

class SectionStats {
  SectionStats(Map<String, dynamic> j)
    : id = j['examSectionId'] as String,
      name = j['sectionName'] as String,
      groupCode = j['groupCode'] as String?,
      groupName = j['groupName'] as String?,
      active = j['isActive'] as bool,
      questions = j['questionCount'] as int,
      count = j['attemptCount'] as int,
      latest = score(j['latestNet']),
      average = score(j['averageNet']),
      best = score(j['bestNet']);
  final String id, name;
  final String? groupCode, groupName;
  final bool active;
  final int questions, count;
  final Score? latest, average, best;
}

class Dashboard {
  Dashboard(Map<String, dynamic> j) {
    final p = j['preparation'] as Map<String, dynamic>,
        s = j['summary'] as Map<String, dynamic>,
        i = j['improvement'] as Map<String, dynamic>;
    preparationId = p['id'] as String;
    examName = p['examName'] as String;
    examCode = p['examCode'] as String;
    target = Score(p['targetNet'] as String);
    date = CalendarDate.parse(p['examDate'] as String);
    days = p['daysRemaining'] as int;
    dateStatus = p['dateStatus'] as String;
    count = s['mockExamCount'] as int;
    latest = score(s['latestNet']);
    average = score(s['averageNet']);
    best = score(s['bestNet']);
    difference = score(s['targetDifference']);
    trend =
        (j['trend'] as List)
            .map((x) => TrendPoint.json(x as Map<String, dynamic>))
            .toList();
    recent =
        (j['recentMocks'] as List)
            .map((x) => TrendPoint.json(x as Map<String, dynamic>))
            .toList();
    sections =
        (j['sections'] as List)
            .map((x) => SectionStats(x as Map<String, dynamic>))
            .toList();
    enough = i['hasEnoughData'] as bool;
    change = score(i['change']);
    if ((count == 0 &&
            [latest, average, best, difference].any((x) => x != null)) ||
        (count > 0 &&
            [latest, average, best, difference].any((x) => x == null)) ||
        (enough && change == null)) {
      throw const FormatException('Invalid dashboard');
    }
  }
  late final String preparationId, examName, examCode, dateStatus;
  late final Score target;
  late final CalendarDate date;
  late final int days, count;
  late final Score? latest, average, best, difference, change;
  late final bool enough;
  late final List<TrendPoint> trend, recent;
  late final List<SectionStats> sections;
}
