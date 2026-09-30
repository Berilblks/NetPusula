import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_issue.dart';
import '../domain/auth_models.dart';

enum AuthStatus { initializing, unauthenticated, authenticated, startupError }

class AuthState {
  const AuthState(this.status, {this.user, this.busy = false, this.issue});
  final AuthStatus status;
  final AuthUser? user;
  final bool busy;
  final AuthIssue? issue;
}

final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig.environment());
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(apiConfigProvider);
  final repository = AuthRepository(
    publicClient: createApiClient(config),
    client: createApiClient(config),
    storage: ref.watch(sessionStorageProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
final apiDioProvider = Provider<Dio>(
  (ref) => ref.watch(authRepositoryProvider).client,
);
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late AuthRepository _repository;
  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    final subscription = _repository.invalidations.listen((issue) {
      if (!ref.mounted) return;
      state = AuthState(
        issue == AuthIssue.storage
            ? AuthStatus.startupError
            : AuthStatus.unauthenticated,
        issue: issue,
      );
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(initialize);
    return const AuthState(AuthStatus.initializing);
  }

  Future<void> initialize() async {
    if (!ref.mounted || state.busy) return;
    state = const AuthState(AuthStatus.initializing, busy: true);
    try {
      final user = await _repository.restore();
      if (!ref.mounted) return;
      // Preserve an invalidation message rather than replacing it with a silent welcome.
      if (state.status == AuthStatus.unauthenticated && state.issue != null) {
        return;
      }
      state = AuthState(
        user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
        user: user,
      );
    } catch (error) {
      if (!ref.mounted) return;
      if (state.status == AuthStatus.unauthenticated && state.issue != null) {
        return;
      }
      state = AuthState(AuthStatus.startupError, issue: mapAuthIssue(error));
    }
  }

  Future<bool> login(String email, String password) =>
      _submit(() => _repository.login(email, password));
  Future<bool> register(String name, String email, String password) =>
      _submit(() => _repository.register(name, email, password));

  Future<bool> _submit(Future<AuthUser> Function() action) async {
    if (state.busy || state.status != AuthStatus.unauthenticated) return false;
    state = const AuthState(AuthStatus.unauthenticated, busy: true);
    try {
      final user = await action();
      if (!ref.mounted) return false;
      state = AuthState(AuthStatus.authenticated, user: user);
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      final issue = mapAuthIssue(error);
      state = AuthState(
        issue == AuthIssue.storage
            ? AuthStatus.startupError
            : AuthStatus.unauthenticated,
        issue: issue,
      );
      return false;
    }
  }

  void clearIssue() {
    if (!state.busy) state = AuthState(state.status, user: state.user);
  }

  Future<void> logout() async {
    if (state.busy) return;
    state = const AuthState(AuthStatus.unauthenticated, busy: true);
    final issue = await _repository.logout();
    if (!ref.mounted) return;
    state = AuthState(
      issue == AuthIssue.storage
          ? AuthStatus.startupError
          : AuthStatus.unauthenticated,
      issue: issue,
    );
  }
}
