import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/google_identity_client.dart';
import '../domain/auth_models.dart';
import '../domain/auth_issue.dart';
import 'auth_text.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final password = TextEditingController();
  AuthUser? user;
  bool busy = false, loading = true, obscure = true;
  String? message;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final value = await ref.read(authRepositoryProvider).currentUser();
      if (mounted) setState(() => user = value);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = AppLocalizations.of(context)!.accountLoadError,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> link() async {
    if (busy || user == null || user!.googleLinked) return;
    final l = AppLocalizations.of(context)!;
    if (password.text.isEmpty) {
      setState(() => message = l.accountPasswordRequired);
      return;
    }
    final repository = ref.read(authRepositoryProvider);
    final generation = repository.generation;
    final localPassword = password.text;
    password.clear();
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final token =
          await ref.read(googleIdentityClientProvider).selectIdToken();
      if (!mounted || repository.generation != generation || token == null) {
        return;
      }
      final value = await repository.linkGoogle(token, localPassword);
      if (!mounted || repository.generation != generation) return;
      setState(() {
        user = value;
        message = l.accountLinkedSuccess;
      });
    } catch (error) {
      if (!mounted || repository.generation != generation) return;
      final data = error is DioException ? error.response?.data : null;
      final code = data is Map ? data['code'] : null;
      setState(
        () =>
            message = switch (code) {
              'reauth_required' => l.accountPasswordIncorrect,
              'google_link_conflict' => l.accountLinkConflict,
              _ => authIssueText(l, mapAuthIssue(error)),
            },
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (user == null)
                    OutlinedButton(onPressed: load, child: Text(l.accountRetry))
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.manage_accounts_outlined,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user!.googleLinked
                                  ? l.accountGoogleLinked
                                  : l.accountGoogleLink,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (!user!.googleLinked) ...[
                              Text(l.accountLinkExplanation),
                              const SizedBox(height: 20),
                              TextField(
                                controller: password,
                                enabled: !busy,
                                obscureText: obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: l.accountCurrentPassword,
                                  suffixIcon: IconButton(
                                    tooltip: l.accountTogglePassword,
                                    onPressed:
                                        () =>
                                            setState(() => obscure = !obscure),
                                    icon: Icon(
                                      obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: busy ? null : link,
                                child:
                                    busy
                                        ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(),
                                        )
                                        : Text(l.accountGoogleLink),
                              ),
                            ] else
                              const Icon(Icons.check_circle_outline),
                          ],
                        ),
                      ),
                    ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(liveRegion: true, child: Text(message!)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
