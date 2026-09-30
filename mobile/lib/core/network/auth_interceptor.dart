import 'dart:async';
import 'package:dio/dio.dart';
import '../../features/auth/domain/auth_issue.dart';

abstract interface class AuthSessionDelegate {
  int get generation;
  Future<String> accessToken();
  Future<String> refreshAfterUnauthorized(String rejectedToken);
  Future<void> invalidate(int expectedGeneration, AuthIssue issue);
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.dio, this.session);
  final Dio dio;
  final AuthSessionDelegate session;
  static const _retried = 'auth.retried';
  static const _generation = 'auth.generation';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final generation = session.generation;
      final token = await session.accessToken();
      if (session.generation != generation) {
        throw const AuthException(AuthIssue.sessionExpired);
      }
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_generation] = generation;
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: AuthException(mapAuthIssue(error)),
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final generation = request.extra[_generation] as int?;
    if (generation == null || generation != session.generation) {
      handler.reject(
        DioException(
          requestOptions: request,
          error: const AuthException(AuthIssue.sessionExpired),
        ),
      );
      return;
    }
    try {
      if (request.extra[_retried] == true) {
        await session.invalidate(generation, AuthIssue.sessionExpired);
        throw const AuthException(AuthIssue.sessionExpired);
      }
      if (request.data is Stream || request.data is FormData) {
        // One-shot payloads must be recreated explicitly by their caller.
        handler.next(err);
        return;
      }
      final sent = (request.headers['Authorization'] as String).substring(7);
      final token = await session.refreshAfterUnauthorized(sent);
      if (generation != session.generation) {
        throw const AuthException(AuthIssue.sessionExpired);
      }
      final response = await dio.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
          extra: {...request.extra, _retried: true},
        ),
      );
      handler.resolve(response);
    } catch (failure) {
      handler.reject(
        DioException(
          requestOptions: request,
          error: AuthException(mapAuthIssue(failure)),
        ),
      );
    }
  }
}
