import '../../preparation/domain/preparation.dart';

// Server decimals travel as strings to avoid JSON binary floating point loss.
String displayNet(String value) {
  if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Invalid net');
  }
  final negative = value.startsWith('-');
  final parts = value.replaceFirst('-', '').split('.');
  final fraction = (parts.length == 1 ? '' : parts[1]).padRight(3, '0');
  var hundredths =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(fraction.substring(0, 2));
  if (int.parse(fraction[2]) >= 5) hundredths += BigInt.one;
  return '${negative && hundredths != BigInt.zero ? '-' : ''}${hundredths ~/ BigInt.from(100)},${(hundredths % BigInt.from(100)).toString().padLeft(2, '0')}';
}

class MockSection {
  const MockSection(
    this.id,
    this.name,
    this.code,
    this.questions, {
    this.groupCode,
    this.groupName,
  });
  final String id, name, code;
  final String? groupCode, groupName;
  final int questions;
  factory MockSection.fromJson(
    Map<String, dynamic> j, {
    bool snapshot = false,
  }) => MockSection(
    j[snapshot ? 'examSectionId' : 'id'] as String,
    j[snapshot ? 'sectionName' : 'name'] as String,
    j[snapshot ? 'sectionCode' : 'code'] as String,
    j['questionCount'] as int,
    groupCode: j['groupCode'] as String?,
    groupName: j['groupName'] as String?,
  );
}

class MockAnswer {
  MockAnswer(this.section, {this.correct = '0', this.wrong = '0'});
  final MockSection section;
  String correct, wrong;
  int? get blank {
    final c = int.tryParse(correct), w = int.tryParse(wrong);
    if (c == null || w == null || c < 0 || w < 0 || c + w > section.questions) {
      return null;
    }
    return section.questions - c - w;
  }

  Map<String, dynamic> get json => {
    'examSectionId': section.id,
    'correctCount': int.parse(correct),
    'wrongCount': int.parse(wrong),
    'blankCount': blank,
  };
}

class MockResult {
  MockResult(this.section, this.correct, this.wrong, this.blank, this.net);
  final MockSection section;
  final int correct, wrong, blank;
  final String net;
  factory MockResult.fromJson(Map<String, dynamic> j) => MockResult(
    MockSection.fromJson(j, snapshot: true),
    j['correctCount'] as int,
    j['wrongCount'] as int,
    j['blankCount'] as int,
    j['net'] as String,
  );
}

class MockExam {
  MockExam(
    this.id,
    this.name,
    this.date,
    this.totalNet, {
    this.notes,
    this.results = const [],
  });
  final String id, name, totalNet;
  final CalendarDate date;
  final String? notes;
  final List<MockResult> results;
  factory MockExam.fromJson(Map<String, dynamic> j) => MockExam(
    j['id'] as String,
    j['name'] as String,
    CalendarDate.parse(j['takenAt'] as String),
    j['totalNet'] as String,
    notes: j['notes'] as String?,
    results:
        (j['results'] as List? ?? [])
            .map((x) => MockResult.fromJson(x as Map<String, dynamic>))
            .toList(),
  );
}

class MockPage {
  MockPage(this.items, this.page, this.totalPages);
  final List<MockExam> items;
  final int page, totalPages;
  factory MockPage.fromJson(Map<String, dynamic> j) => MockPage(
    (j['items'] as List)
        .map((x) => MockExam.fromJson(x as Map<String, dynamic>))
        .toList(),
    j['page'] as int,
    j['totalPages'] as int,
  );
}

class MockDraft {
  MockDraft(
    this.date, {
    this.id,
    this.name = '',
    this.notes = '',
    required this.answers,
  });
  final String? id;
  String name, notes;
  CalendarDate date;
  final List<MockAnswer> answers;
  factory MockDraft.edit(MockExam exam) => MockDraft(
    exam.date,
    id: exam.id,
    name: exam.name,
    notes: exam.notes ?? '',
    answers:
        exam.results
            .map(
              (r) => MockAnswer(
                r.section,
                correct: '${r.correct}',
                wrong: '${r.wrong}',
              ),
            )
            .toList(),
  );
  bool valid(CalendarDate today) =>
      name.trim().isNotEmpty &&
      name.trim().length <= 200 &&
      notes.length <= 4000 &&
      date.compareTo(today) <= 0 &&
      answers.isNotEmpty &&
      answers.every((a) => a.blank != null);
  Map<String, dynamic> get json => {
    'name': name.trim(),
    'takenAt': date.iso,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
    'results': answers.map((a) => a.json).toList(),
  };
}
