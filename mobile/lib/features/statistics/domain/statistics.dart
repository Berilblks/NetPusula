import '../../dashboard/domain/dashboard.dart';
import '../../preparation/domain/preparation.dart';

class StatisticsMetrics {
  StatisticsMetrics(Map<String, dynamic> j)
    : count = j['attemptCount'] as int,
      latest = score(j['latestNet']),
      average = score(j['averageNet']),
      best = score(j['bestNet']),
      worst = score(j['worstNet']) {
    if (count < 0 ||
        [
          latest,
          average,
          best,
          worst,
        ].any((v) => (count == 0) != (v == null))) {
      throw const FormatException('Invalid statistics metrics');
    }
  }
  final int count;
  final Score? latest, average, best, worst;
}

class StatisticsChange {
  StatisticsChange(Map<String, dynamic> j)
    : enough = j['sufficientData'] as bool,
      change = score(j['change']),
      recent = score(j['recentAverage']),
      previous = score(j['previousAverage']) {
    if ([change, recent, previous].any((v) => enough != (v != null))) {
      throw const FormatException('Invalid comparison');
    }
  }
  final bool enough;
  final Score? change, recent, previous;
}

class StatisticsSection {
  StatisticsSection(Map<String, dynamic> j)
    : id = j['examSectionId'] as String,
      name = j['sectionName'] as String,
      groupCode = j['groupCode'] as String?,
      groupName = j['groupName'] as String?,
      active = j['isActive'] as bool,
      metrics = StatisticsMetrics(j),
      change = StatisticsChange(j['improvement'] as Map<String, dynamic>),
      correct = score(j['answers']['correct']),
      wrong = score(j['answers']['wrong']),
      blank = score(j['answers']['blank']),
      series =
          (j['series'] as List)
              .map((p) => SectionAnswer(p as Map<String, dynamic>))
              .toList();
  final String id, name;
  final String? groupCode, groupName;
  final bool active;
  final StatisticsMetrics metrics;
  final StatisticsChange change;
  final Score? correct, wrong, blank;
  final List<SectionAnswer> series;
}

class SectionAnswer {
  SectionAnswer(Map<String, dynamic> j)
    : point = TrendPoint(
        j['mockExamId'] as String,
        '',
        CalendarDate.parse(j['takenAt'] as String),
        Score(j['net'] as String),
      ),
      correct = j['correctCount'] as int,
      wrong = j['wrongCount'] as int,
      blank = j['blankCount'] as int;
  final TrendPoint point;
  final int correct, wrong, blank;
}

class Statistics {
  Statistics(Map<String, dynamic> j)
    : target = Score(j['targetNet'] as String),
      selection = j['range']['selection'] as String,
      limit = j['range']['limit'] as int,
      available = j['range']['availableAttemptCount'] as int,
      capped = j['range']['isCapped'] as bool,
      metrics = StatisticsMetrics(j['summary'] as Map<String, dynamic>),
      change = StatisticsChange(j['improvement'] as Map<String, dynamic>),
      series =
          (j['series'] as List)
              .map((p) => TrendPoint.json(p as Map<String, dynamic>))
              .toList(),
      best =
          j['bestMock'] == null
              ? null
              : TrendPoint.json(j['bestMock'] as Map<String, dynamic>),
      sections =
          (j['sections'] as List)
              .map((s) => StatisticsSection(s as Map<String, dynamic>))
              .toList(),
      first = j['activity']['firstMockDate'] as String?,
      last = j['activity']['lastMockDate'] as String?,
      interval = score(j['activity']['averageDaysBetweenMocks']);
  final Score target;
  final String selection;
  final int limit, available;
  final bool capped;
  final StatisticsMetrics metrics;
  final StatisticsChange change;
  final List<TrendPoint> series;
  final TrendPoint? best;
  final List<StatisticsSection> sections;
  final String? first, last;
  final Score? interval;
}
