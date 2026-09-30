import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../../features/auth/domain/auth_issue.dart';

Dio createApiClient(ApiConfig config) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.isValid ? config.baseUrl : '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        // Never send credentials to a different origin or follow credential-bearing redirects.
        if (!config.isValid || request.uri.origin != config.uri!.origin) {
          handler.reject(
            DioException(
              requestOptions: request,
              error: const AuthException(AuthIssue.configuration),
            ),
          );
          return;
        }
        handler.next(request);
      },
    ),
  );
  // Intentionally no LogInterceptor, certificate bypass or automatic POST retries.
  return dio;
}
