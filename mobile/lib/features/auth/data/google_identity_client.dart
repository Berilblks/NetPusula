import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_issue.dart';

abstract interface class GoogleIdentityClient {
  /// Null means the user canceled. Only an ID token is exchanged with our API.
  Future<String?> selectIdToken();
}

final googleIdentityClientProvider = Provider<GoogleIdentityClient>(
  (ref) => SdkGoogleIdentityClient(),
);

class SdkGoogleIdentityClient implements GoogleIdentityClient {
  static Future<void>? _initialization;
  @override
  Future<String?> selectIdToken() async {
    const server = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    const ios = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform) ||
        server.isEmpty ||
        (defaultTargetPlatform == TargetPlatform.iOS && ios.isEmpty)) {
      throw const AuthException(AuthIssue.googleUnavailable);
    }
    try {
      final sdk = GoogleSignIn.instance;
      _initialization ??= sdk.initialize(
        serverClientId: server,
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? ios : null,
      );
      await _initialization;
      // Clear the previous SDK selection so the explicit action can choose an account.
      // This does not revoke Google consent or log out the user's device account.
      await sdk.signOut();
      final user = await sdk.authenticate();
      final token = user.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AuthException(AuthIssue.googleRejected);
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const AuthException(AuthIssue.googleUnavailable);
      }
      throw const AuthException(AuthIssue.googleRejected);
    }
  }
}
