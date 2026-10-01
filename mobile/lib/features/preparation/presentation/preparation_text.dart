import '../../../l10n/app_localizations.dart';
import '../data/preparation_repository.dart';
import '../domain/preparation.dart';

String preparationIssueText(AppLocalizations l, PreparationIssue issue) =>
    switch (issue) {
      PreparationIssue.validation => l.prepValidation,
      PreparationIssue.target => l.prepTargetInvalid,
      PreparationIssue.date => l.prepDateInvalid,
      PreparationIssue.missing => l.prepMissing,
      PreparationIssue.conflict => l.prepConflict,
      PreparationIssue.rateLimited => l.rateLimited,
      PreparationIssue.network => l.prepNetwork,
      PreparationIssue.session => l.sessionExpired,
      PreparationIssue.unexpected => l.prepSaveError,
    };
String remainingText(
  AppLocalizations l,
  CalendarDate date,
  CalendarDate today,
) {
  final compared = date.compareTo(today);
  if (compared < 0) return l.examPassed;
  return compared == 0
      ? l.examToday
      : l.daysRemaining(date.daysRemaining(today));
}
