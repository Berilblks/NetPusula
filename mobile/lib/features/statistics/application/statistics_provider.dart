import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../preparation/application/preparation_controller.dart';
import '../domain/statistics.dart';

class StatisticsRepository {
  StatisticsRepository(this.client);
  final Dio client;
  Future<Statistics> get(String range) async => Statistics(
    (await client.get<Map<String, dynamic>>(
      '/api/statistics',
      queryParameters: {'range': range},
    )).data!,
  );
}

final statisticsRepositoryProvider = Provider(
  (ref) => StatisticsRepository(ref.watch(authRepositoryProvider).client),
);
// A distinct provider per range prevents late responses replacing a newer selection.
final statisticsProvider = FutureProvider.autoDispose
    .family<Statistics, String>((ref, range) {
      final auth = ref.watch(
        authControllerProvider.select((s) => (s.status, s.user?.id)),
      );
      final prep = ref.watch(
        preparationControllerProvider.select((s) => s.active),
      );
      if (auth.$1 != AuthStatus.authenticated || prep == null) {
        throw StateError('Statistics unavailable');
      }
      return ref.watch(statisticsRepositoryProvider).get(range);
    });
