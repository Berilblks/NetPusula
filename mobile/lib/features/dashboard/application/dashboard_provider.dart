import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../preparation/application/preparation_controller.dart';
import '../domain/dashboard.dart';

class DashboardRepository {
  DashboardRepository(this.client);
  final Dio client;
  Future<Dashboard> get() async => Dashboard(
    (await client.get<Map<String, dynamic>>('/api/dashboard')).data!,
  );
}

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(authRepositoryProvider).client),
);
final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  final auth = ref.watch(
    authControllerProvider.select((s) => (s.status, s.user?.id)),
  );
  // Includes target/date updates as well as replacement preparation IDs.
  final preparation = ref.watch(
    preparationControllerProvider.select((s) => s.active),
  );
  if (auth.$1 != AuthStatus.authenticated || preparation == null) {
    throw StateError('Dashboard unavailable');
  }
  final result = await ref.watch(dashboardRepositoryProvider).get();
  return result;
});
