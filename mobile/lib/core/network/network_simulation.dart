import 'package:dio/dio.dart';

/// How requests fail in a simulated network.
enum SimulatedFault {
  none,

  /// Every request fails like a lost connection.
  offline,

  /// Every request fails like a connect timeout.
  timeout,

  /// Every [NetworkSimulation.flakyEvery]th request fails like a lost
  /// connection.
  flaky;

  /// The fault named [value], or [none] for anything else.
  static SimulatedFault parse(String value) => values.firstWhere(
    (fault) => fault.name == value.trim().toLowerCase(),
    orElse: () => none,
  );
}

/// Settings for [NetworkSimulationInterceptor], read from `--dart-define`
/// (see `AppConfig`).
class NetworkSimulation {
  const NetworkSimulation({
    this.latency = Duration.zero,
    this.fault = SimulatedFault.none,
  });

  /// Builds the settings from the raw `--dart-define` values. A negative or
  /// missing latency is zero and an unknown fault name is [SimulatedFault.none].
  factory NetworkSimulation.fromValues({
    required int latencyMs,
    required String fault,
  }) => NetworkSimulation(
    latency: Duration(milliseconds: latencyMs < 0 ? 0 : latencyMs),
    fault: SimulatedFault.parse(fault),
  );

  /// Every request waits this long before it is sent.
  final Duration latency;

  final SimulatedFault fault;

  /// For [SimulatedFault.flaky]: the failing request's position in each run.
  static const flakyEvery = 3;

  /// Whether anything is simulated. When false the interceptor is not added.
  bool get isActive => latency > Duration.zero || fault != SimulatedFault.none;
}

/// Makes a fast, working connection behave like a bad one, so loading, retry
/// and error states can be seen while developing.
///
/// Dev only: the Dio modules add it in debug builds when a setting is set,
/// never in profile or release builds.
class NetworkSimulationInterceptor extends Interceptor {
  NetworkSimulationInterceptor(this.simulation);

  final NetworkSimulation simulation;
  int _requests = 0;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _requests++;
    if (simulation.latency > Duration.zero) {
      await Future<void>.delayed(simulation.latency);
    }
    final type = _failure();
    if (type == null) return handler.next(options);
    handler.reject(
      DioException(
        requestOptions: options,
        type: type,
        message: 'Simulated network fault: ${simulation.fault.name}',
      ),
      true,
    );
  }

  DioExceptionType? _failure() => switch (simulation.fault) {
    SimulatedFault.none => null,
    SimulatedFault.offline => DioExceptionType.connectionError,
    SimulatedFault.timeout => DioExceptionType.connectionTimeout,
    SimulatedFault.flaky =>
      _requests % NetworkSimulation.flakyEvery == 0
          ? DioExceptionType.connectionError
          : null,
  };
}
