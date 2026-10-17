import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/network/dio_client.dart';
import 'package:stridequest/core/network/network_simulation.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  Dio dioWith(NetworkSimulation simulation) {
    adapter = FakeHttpAdapter((_) async => jsonBody({'ok': true}, 200));
    return createDio(
      baseUrl: 'http://api.test/',
      adapter: adapter,
      interceptors: [NetworkSimulationInterceptor(simulation)],
    );
  }

  Future<DioExceptionType?> failureOf(Dio dio) async {
    try {
      await dio.get<dynamic>('runs');
    } on DioException catch (error) {
      return error.type;
    }
    return null;
  }

  group('NetworkSimulation', () {
    test('is inactive by default', () {
      expect(const NetworkSimulation().isActive, isFalse);
      expect(
        NetworkSimulation.fromValues(latencyMs: 0, fault: 'none').isActive,
        isFalse,
      );
    });

    test('is active with a latency or a fault', () {
      expect(
        NetworkSimulation.fromValues(latencyMs: 200, fault: 'none').isActive,
        isTrue,
      );
      expect(
        NetworkSimulation.fromValues(latencyMs: 0, fault: 'offline').isActive,
        isTrue,
      );
    });

    test('reads the fault name, ignoring case, and treats unknown as none', () {
      expect(SimulatedFault.parse('Timeout'), SimulatedFault.timeout);
      expect(SimulatedFault.parse(' flaky '), SimulatedFault.flaky);
      expect(SimulatedFault.parse('banana'), SimulatedFault.none);
      expect(SimulatedFault.parse(''), SimulatedFault.none);
    });

    test('treats a negative latency as zero', () {
      expect(
        NetworkSimulation.fromValues(latencyMs: -5, fault: 'none').latency,
        Duration.zero,
      );
    });
  });

  group('NetworkSimulationInterceptor', () {
    test('delays each request by the latency', () async {
      final dio = dioWith(
        const NetworkSimulation(latency: Duration(milliseconds: 120)),
      );
      final stopwatch = Stopwatch()..start();

      await dio.get<dynamic>('runs');

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(120));
      expect(adapter.requests, hasLength(1));
    });

    test('passes requests through with no fault', () async {
      final dio = dioWith(const NetworkSimulation());

      expect(await failureOf(dio), isNull);
      expect(adapter.requests, hasLength(1));
    });

    test('offline fails every request as a connection error', () async {
      final dio = dioWith(
        const NetworkSimulation(fault: SimulatedFault.offline),
      );

      expect(await failureOf(dio), DioExceptionType.connectionError);
      expect(await failureOf(dio), DioExceptionType.connectionError);
      expect(adapter.requests, isEmpty);
    });

    test('timeout fails every request as a connect timeout', () async {
      final dio = dioWith(
        const NetworkSimulation(fault: SimulatedFault.timeout),
      );

      expect(await failureOf(dio), DioExceptionType.connectionTimeout);
      expect(adapter.requests, isEmpty);
    });

    test('flaky fails every third request', () async {
      final dio = dioWith(const NetworkSimulation(fault: SimulatedFault.flaky));

      final results = [for (var i = 0; i < 6; i++) await failureOf(dio)];

      expect(results, [
        null,
        null,
        DioExceptionType.connectionError,
        null,
        null,
        DioExceptionType.connectionError,
      ]);
      expect(adapter.requests, hasLength(4));
    });

    test('latency applies before a fault', () async {
      final dio = dioWith(
        const NetworkSimulation(
          latency: Duration(milliseconds: 100),
          fault: SimulatedFault.offline,
        ),
      );
      final stopwatch = Stopwatch()..start();

      await failureOf(dio);

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
    });
  });
}
