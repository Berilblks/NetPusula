import '../../statistics/application/statistics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/application/dashboard_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../preparation/application/preparation_controller.dart';
import '../../preparation/domain/preparation.dart';
import '../data/mock_exam_repository.dart';
import '../domain/mock_exam.dart';

final mockRepositoryProvider = Provider((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return MockExamRepository(auth.client, auth.publicClient);
});
// These dependencies dispose cached results and drafts on user/preparation changes.
final mockScopeProvider = Provider(
  (ref) => (
    ref.watch(authControllerProvider.select((s) => s.user?.id)),
    ref.watch(preparationControllerProvider.select((s) => s.active?.id)),
  ),
);
final mockDetailProvider = FutureProvider.autoDispose.family<MockExam, String>((
  ref,
  id,
) {
  ref.watch(mockScopeProvider);
  return ref.watch(mockRepositoryProvider).detail(id);
});
final mockDraftProvider = FutureProvider.autoDispose.family<MockDraft, String?>(
  (ref, id) async {
    ref.watch(mockScopeProvider);
    final repository = ref.watch(mockRepositoryProvider);
    if (id != null) return MockDraft.edit(await repository.detail(id));
    final active = ref.watch(preparationControllerProvider).active;
    if (active == null) throw StateError('Preparation required');
    final sections = await repository.sections(active.exam.id);
    return MockDraft(
      CalendarDate.local(ref.read(localNowProvider)()),
      answers: sections.map(MockAnswer.new).toList(),
    );
  },
);

class MockHistoryState {
  const MockHistoryState({
    this.items = const [],
    this.page = 0,
    this.totalPages = 1,
    this.loading = false,
    this.issue,
  });
  final List<MockExam> items;
  final int page, totalPages;
  final bool loading;
  final MockIssue? issue;
}

final mockHistoryProvider =
    NotifierProvider.autoDispose<MockHistoryController, MockHistoryState>(
      MockHistoryController.new,
    );

class MockHistoryController extends Notifier<MockHistoryState> {
  int _epoch = 0;
  @override
  MockHistoryState build() {
    ref.watch(mockScopeProvider);
    final epoch = ++_epoch;
    Future.microtask(() {
      if (ref.mounted && epoch == _epoch) load();
    });
    return const MockHistoryState(loading: true);
  }

  Future<void> load({bool more = false}) async {
    if (more && (state.loading || state.page >= state.totalPages)) return;
    final before = state;
    final epoch = ++_epoch;
    state = MockHistoryState(
      items: more ? before.items : [],
      page: more ? before.page : 0,
      totalPages: before.totalPages,
      loading: true,
    );
    try {
      final result = await ref
          .read(mockRepositoryProvider)
          .list(more ? before.page + 1 : 1);
      if (!ref.mounted || epoch != _epoch) return;
      state = MockHistoryState(
        items: [if (more) ...before.items, ...result.items],
        page: result.page,
        totalPages: result.totalPages,
      );
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        state = MockHistoryState(
          items: more ? before.items : [],
          page: more ? before.page : 0,
          totalPages: before.totalPages,
          issue: mockIssue(error),
        );
      }
    }
  }
}

class MockMutationState {
  const MockMutationState({this.busy = false, this.issue});
  final bool busy;
  final MockIssue? issue;
}

final mockMutationProvider =
    NotifierProvider.autoDispose<MockMutationController, MockMutationState>(
      MockMutationController.new,
    );

class MockMutationController extends Notifier<MockMutationState> {
  int _epoch = 0;
  @override
  MockMutationState build() {
    ref.watch(mockScopeProvider);
    ++_epoch;
    return const MockMutationState();
  }

  Future<MockExam?> save(MockDraft draft) async {
    if (state.busy) return null;
    final epoch = ++_epoch;
    state = const MockMutationState(busy: true);
    try {
      final result = await ref.read(mockRepositoryProvider).save(draft);
      if (!ref.mounted || epoch != _epoch) return null;
      ref.invalidate(mockHistoryProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(mockDetailProvider(result.id));
      state = const MockMutationState();
      return result;
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        state = MockMutationState(issue: mockIssue(error));
      }
      return null;
    }
  }

  Future<bool> delete(String id) async {
    if (state.busy) return false;
    final epoch = ++_epoch;
    state = const MockMutationState(busy: true);
    try {
      await ref.read(mockRepositoryProvider).delete(id);
      if (!ref.mounted || epoch != _epoch) return false;
      ref.invalidate(mockHistoryProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(mockDetailProvider(id));
      state = const MockMutationState();
      return true;
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        state = MockMutationState(issue: mockIssue(error));
      }
      return false;
    }
  }
}
