import 'package:dio/dio.dart';
import '../../auth/domain/auth_issue.dart';
import '../domain/preparation.dart';

enum PreparationIssue {
  validation,
  target,
  date,
  missing,
  conflict,
  rateLimited,
  network,
  session,
  unexpected,
}

class PreparationException implements Exception {
  const PreparationException(this.issue);
  final PreparationIssue issue;
  @override
  String toString() => 'Preparation request failed';
}

PreparationIssue preparationIssue(Object error) {
  if (error is PreparationException) return error.issue;
  if (error is DioException) {
    switch (error.response?.statusCode) {
      case 400:
        final data = error.response?.data;
        final fields = data is Map ? data['errors'] : null;
        if (fields is Map && fields.containsKey('examDate')) {
          return PreparationIssue.date;
        }
        if (fields is Map && fields.containsKey('targetNet')) {
          return PreparationIssue.target;
        }
        return PreparationIssue.validation;
      case 404:
        return PreparationIssue.missing;
      case 409:
        return PreparationIssue.conflict;
      case 429:
        return PreparationIssue.rateLimited;
    }
  }
  return switch (mapAuthIssue(error)) {
    AuthIssue.network => PreparationIssue.network,
    AuthIssue.sessionExpired ||
    AuthIssue.invalidCredentials => PreparationIssue.session,
    _ => PreparationIssue.unexpected,
  };
}

class PreparationRepository {
  PreparationRepository(this.client, this.catalogue);
  final Dio client, catalogue;
  Future<Preparation?> active() async {
    final response = await client.get<dynamic>('/api/user-exams/active');
    if (response.statusCode == 204) return null;
    return Preparation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PreparationExam>> exams() async {
    final response = await catalogue.get<dynamic>('/api/exams');
    return (response.data as List)
        .map((x) => PreparationExam.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  Future<Preparation> save({
    String? id,
    required PreparationExam exam,
    required NetTarget target,
    required CalendarDate date,
  }) async {
    final data = <String, dynamic>{
      'targetNet': target.jsonNumber,
      'examDate': date.iso,
    };
    if (id == null) data['examId'] = exam.id;
    final response =
        id == null
            ? await client.post<dynamic>('/api/user-exams', data: data)
            : await client.put<dynamic>('/api/user-exams/$id', data: data);
    return Preparation.fromJson(response.data as Map<String, dynamic>);
  }
}
