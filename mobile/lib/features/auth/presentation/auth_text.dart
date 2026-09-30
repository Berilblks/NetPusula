import '../../../l10n/app_localizations.dart';
import '../domain/auth_issue.dart';

String authIssueText(AppLocalizations l10n, AuthIssue issue) => switch (issue) {
  AuthIssue.invalidCredentials => l10n.invalidCredentials,
  AuthIssue.invalidEmail => l10n.emailInvalid,
  AuthIssue.invalidName => l10n.nameInvalid,
  AuthIssue.weakPassword => l10n.passwordPolicy,
  AuthIssue.validation => l10n.validationError,
  AuthIssue.duplicateEmail => l10n.duplicateEmail,
  AuthIssue.rateLimited => l10n.rateLimited,
  AuthIssue.network => l10n.networkError,
  AuthIssue.unexpected => l10n.unexpectedError,
  AuthIssue.sessionExpired => l10n.sessionExpired,
  AuthIssue.storage => l10n.storageError,
  AuthIssue.configuration => l10n.configurationError,
  AuthIssue.localLogout => l10n.localLogout,
};

class AuthValidation {
  static bool email(String value) {
    final email = value.trim();
    return email.length <= 254 &&
        email.codeUnits.every((c) => c > 32 && c < 127) &&
        RegExp(
          r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$",
        ).hasMatch(email) &&
        !email.startsWith('.') &&
        !email.contains('..');
  }

  static bool name(String value) =>
      value.trim().length >= 2 &&
      value.trim().length <= 120 &&
      !_control.hasMatch(value.trim());
  static bool password(String value) =>
      value.length >= 8 &&
      value.length <= 128 &&
      value.codeUnits.any(
        (unit) => _letter.hasMatch(String.fromCharCode(unit)),
      ) &&
      value.codeUnits.any(
        (unit) => _digit.hasMatch(String.fromCharCode(unit)),
      ) &&
      !_control.hasMatch(value);
  // Backend uses char.IsLetter/IsDigit on UTF-16 code units, not Unicode runes.
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _digit = RegExp(r'\p{Nd}', unicode: true);
  static final _control = RegExp(r'[\x00-\x1F\x7F-\x9F]');
}
