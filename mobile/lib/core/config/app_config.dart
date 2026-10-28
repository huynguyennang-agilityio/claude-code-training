import 'package:flutter/foundation.dart';

import '../network/network_simulation.dart';
import 'api_mode.dart';

/// Build-time settings, passed with `--dart-define`.
abstract final class AppConfig {
  /// Dev only: `mock` to use the fake remote data sources instead of the API.
  /// Profile and release builds always use [ApiMode.real].
  static final apiMode = resolveApiMode(
    const String.fromEnvironment('API_MODE'),
    isDebug: kDebugMode,
  );

  /// The StrideQuest API base, including the `/api/v1/` prefix
  /// (see `docs/api/auth.md`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1/',
  );

  /// Dev only: wait this many milliseconds before every request.
  static const simulatedLatencyMs = int.fromEnvironment('SIMULATE_LATENCY_MS');

  /// Dev only: `offline`, `timeout` or `flaky` (every 3rd request fails).
  static const simulatedFault = String.fromEnvironment(
    'SIMULATE_FAULT',
    defaultValue: 'none',
  );

  /// The network simulation these settings describe. It only takes effect in
  /// debug builds (see `NetworkModule`).
  static final networkSimulation = NetworkSimulation.fromValues(
    latencyMs: simulatedLatencyMs,
    fault: simulatedFault,
  );
}
