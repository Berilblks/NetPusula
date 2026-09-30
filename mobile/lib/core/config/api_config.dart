import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig(this.baseUrl, {this.allowHttp = false});
  factory ApiConfig.environment() => const ApiConfig(
    String.fromEnvironment('API_BASE_URL'),
    allowHttp: kDebugMode && bool.fromEnvironment('ALLOW_INSECURE_HTTP'),
  );

  final String baseUrl;
  final bool allowHttp;
  Uri? get uri => Uri.tryParse(baseUrl);
  bool get isValid {
    final value = uri;
    return value != null &&
        value.hasAuthority &&
        value.host.isNotEmpty &&
        value.userInfo.isEmpty &&
        !value.hasQuery &&
        !value.hasFragment &&
        (value.path.isEmpty || value.path == '/') &&
        (value.scheme == 'https' || (allowHttp && value.scheme == 'http'));
  }
}
