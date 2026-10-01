import 'package:dio/dio.dart';
import '../domain/mock_exam.dart';
import '../../auth/domain/auth_issue.dart';

class MockExamRepository {
  MockExamRepository(this.client, this.catalogue);
  final Dio client, catalogue;
  Future<MockPage> list(int page) async => MockPage.fromJson(
    (await client.get<Map<String, dynamic>>(
      '/api/mock-exams',
      queryParameters: {'page': page, 'pageSize': 20},
    )).data!,
  );
  Future<MockExam> detail(String id) async => MockExam.fromJson(
    (await client.get<Map<String, dynamic>>('/api/mock-exams/$id')).data!,
  );
  Future<List<MockSection>> sections(String exam) async =>
      ((await catalogue.get<List<dynamic>>('/api/exams/$exam/sections')).data!)
          .map((x) => MockSection.fromJson(x as Map<String, dynamic>))
          .toList();
  Future<MockExam> save(MockDraft draft) async {
    final response =
        draft.id == null
            ? await client.post<Map<String, dynamic>>(
              '/api/mock-exams',
              data: draft.json,
            )
            : await client.put<Map<String, dynamic>>(
              '/api/mock-exams/${draft.id}',
              data: draft.json,
            );
    return MockExam.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await client.delete<void>('/api/mock-exams/$id');
  }
}

enum MockIssue {
  validation,
  session,
  missing,
  noPreparation,
  conflict,
  rateLimited,
  network,
  server,
}

MockIssue mockIssue(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (error.response?.statusCode == 409 &&
        data is Map &&
        data['code'] == 'active_preparation_required') {
      return MockIssue.noPreparation;
    }
    switch (error.response?.statusCode) {
      case 400:
        return MockIssue.validation;
      case 401:
        return MockIssue.session;
      case 404:
        return MockIssue.missing;
      case 409:
        return MockIssue.conflict;
      case 429:
        return MockIssue.rateLimited;
    }
    if ({
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type)) {
      return MockIssue.network;
    }
  }
  return switch (mapAuthIssue(error)) {
    AuthIssue.sessionExpired ||
    AuthIssue.invalidCredentials => MockIssue.session,
    AuthIssue.network => MockIssue.network,
    _ => MockIssue.server,
  };
}
