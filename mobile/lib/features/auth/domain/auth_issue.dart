import 'package:dio/dio.dart';

enum AuthIssue {
  invalidCredentials,
  validation,
  invalidEmail,
  weakPassword,
  invalidName,
  duplicateEmail,
  rateLimited,
  network,
  unexpected,
  sessionExpired,
  storage,
  configuration,
  localLogout,
}

class AuthException implements Exception {
  const AuthException(this.issue);
  final AuthIssue issue;
  @override
  String toString() => 'Authentication operation failed';
}

AuthIssue mapAuthIssue(Object error) {
  if (error is AuthException) return error.issue;
  if (error is! DioException) return AuthIssue.unexpected;
  if (error.error is AuthException) return (error.error as AuthException).issue;
  if ({
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  }.contains(error.type)) {
    return AuthIssue.network;
  }
  switch (error.response?.statusCode) {
    case 400:
      final data = error.response?.data;
      final fields = data is Map ? data['errors'] : null;
      if (fields is Map) {
        if (fields.containsKey('email')) return AuthIssue.invalidEmail;
        if (fields.containsKey('password')) return AuthIssue.weakPassword;
        if (fields.containsKey('displayName')) return AuthIssue.invalidName;
      }
      return AuthIssue.validation;
    case 401:
      return AuthIssue.invalidCredentials;
    case 409:
      return AuthIssue.duplicateEmail;
    case 429:
      return AuthIssue.rateLimited;
    default:
      return AuthIssue.unexpected;
  }
}
