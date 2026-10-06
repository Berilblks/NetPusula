import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../data/preparation_repository.dart';
import '../domain/preparation.dart';

enum PreparationStatus { idle, loading, none, ready, error }

class PreparationState {
  const PreparationState(
    this.status, {
    this.active,
    this.issue,
    this.saving = false,
  });
  final PreparationStatus status;
  final Preparation? active;
  final PreparationIssue? issue;
  final bool saving;
}

final preparationRepositoryProvider = Provider((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return PreparationRepository(auth.client, auth.publicClient);
});
final preparationControllerProvider =
    NotifierProvider<PreparationController, PreparationState>(
      PreparationController.new,
    );
final localNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final examCatalogueProvider = FutureProvider.autoDispose<List<PreparationExam>>(
  (ref) => ref.watch(preparationRepositoryProvider).exams(),
  retry: (_, _) => null,
);

class PreparationController extends Notifier<PreparationState> {
  int _epoch = 0;
  @override
  PreparationState build() {
    final userId = ref.watch(
      authControllerProvider.select(
        (s) => s.status == AuthStatus.authenticated ? s.user?.id : null,
      ),
    );
    ref.watch(preparationRepositoryProvider);
    final epoch = ++_epoch;
    if (userId == null) return const PreparationState(PreparationStatus.idle);
    Future.microtask(() {
      if (ref.mounted && epoch == _epoch) load();
    });
    return const PreparationState(PreparationStatus.loading);
  }

  Future<void> load() async {
    if (!ref.mounted ||
        state.saving ||
        ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      return;
    }
    final epoch = ++_epoch;
    state = const PreparationState(PreparationStatus.loading);
    try {
      final active = await ref.read(preparationRepositoryProvider).active();
      if (!ref.mounted ||
          epoch != _epoch ||
          ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return;
      }
      state = PreparationState(
        active == null ? PreparationStatus.none : PreparationStatus.ready,
        active: active,
      );
    } catch (error) {
      if (ref.mounted &&
          epoch == _epoch &&
          ref.read(authControllerProvider).status == AuthStatus.authenticated) {
        state = PreparationState(
          PreparationStatus.error,
          issue: preparationIssue(error),
        );
      }
    }
  }

  Future<bool> save({
    String? id,
    required PreparationExam exam,
    required NetTarget target,
    required CalendarDate date,
  }) async {
    if (state.saving ||
        !{
          PreparationStatus.none,
          PreparationStatus.ready,
        }.contains(state.status)) {
      return false;
    }
    final before = state;
    final epoch = ++_epoch;
    state = PreparationState(
      before.status,
      active: before.active,
      saving: true,
    );
    try {
      final result = await ref
          .read(preparationRepositoryProvider)
          .save(id: id, exam: exam, target: target, date: date);
      if (!ref.mounted ||
          epoch != _epoch ||
          ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return false;
      }
      state = PreparationState(PreparationStatus.ready, active: result);
      return true;
    } catch (error) {
      if (ref.mounted &&
          epoch == _epoch &&
          ref.read(authControllerProvider).status == AuthStatus.authenticated) {
        state = PreparationState(
          before.status,
          active: before.active,
          issue: preparationIssue(error),
        );
      }
      return false;
    }
  }
}
