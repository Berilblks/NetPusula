class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
  });
  final String id;
  final String displayName;
  final String email;
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: requiredString(json, 'id'),
    displayName: requiredString(json, 'displayName'),
    email: requiredString(json, 'email'),
  );
}

String requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid auth response');
  }
  return value;
}

class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    this.refreshPending = false,
  });
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final bool refreshPending;

  factory SessionTokens.fromJson(Map<String, dynamic> json) => SessionTokens(
    accessToken: requiredString(json, 'accessToken'),
    refreshToken: requiredString(json, 'refreshToken'),
    accessExpiresAt:
        DateTime.parse(requiredString(json, 'accessTokenExpiresAtUtc')).toUtc(),
    refreshExpiresAt:
        DateTime.parse(
          requiredString(json, 'refreshTokenExpiresAtUtc'),
        ).toUtc(),
    refreshPending: json['refreshPending'] == true,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAtUtc': accessExpiresAt.toIso8601String(),
    'refreshTokenExpiresAtUtc': refreshExpiresAt.toIso8601String(),
    'refreshPending': refreshPending,
  };

  SessionTokens pending() => SessionTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt,
    refreshPending: true,
  );
  // Deliberately no token-bearing toString().
}
