import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/health_access.dart';
import '../domain/failures/runs_failure.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/services/health_sync.dart';
import '../domain/usecases/sync_activity.dart';

/// Syncs the health data when the app opens, comes back to the foreground and
/// when a session starts, so the Active tab is not the only way data reaches the
/// backend. One app-wide service (not a bloc): screens read [state] and [stream].
///
/// A sync runs only when someone is signed in and steps may be read. Two
/// triggers at once share one run (single-flight). A trigger within [throttle]
/// of the end of the last successful sync does nothing, unless it is forced or
/// the allowed metrics changed since. A forced trigger, or one after the session
/// changed, queues one follow-up run behind the one in flight; the in-flight
/// run's result is dropped when the session changed under it.
/// A run that threw a `HealthFailure` or returned a `RunsFailure` does not
/// start the throttle, so the next trigger retries.
@LazySingleton(as: HealthSync)
class HealthSyncService implements HealthSync {
  HealthSyncService(
    HealthRepository health,
    AuthRepository auth,
    SyncActivity sync,
  ) : this.withClock(health, auth, sync, DateTime.now);

  @visibleForTesting
  HealthSyncService.withClock(
    this._health,
    this._auth,
    this._sync,
    this._clock,
  );

  /// The time a finished sync keeps further triggers quiet.
  static const throttle = Duration(minutes: 5);

  final HealthRepository _health;
  final AuthRepository _auth;
  final SyncActivity _sync;
  final DateTime Function() _clock;

  final _controller = StreamController<HealthSyncState>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;
  Future<void>? _running;
  Future<void>? _followUp;
  int _runGeneration = 0;
  // Bumped by every session change; a run that started earlier is stale.
  int _generation = 0;
  DateTime? _lastSuccessAt;
  Set<HealthMetric>? _lastAllowed;
  HealthSyncState _state = const HealthSyncState();

  /// The latest state; it never goes back to empty while the app runs, except
  /// when the session ends.
  @override
  HealthSyncState get state => _state;

  /// Every change of [state].
  @override
  Stream<HealthSyncState> get stream => _controller.stream;

  /// Listens for resume and for new or ended sessions, and runs the cold-start
  /// sync. Call once, after the dependencies are set up.
  @override
  void start() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    _subscriptions
      ..add(
        _auth.sessionStarted.listen((_) {
          _reset();
          unawaited(sync(force: true));
        }),
      )
      ..add(_auth.sessionEnded.listen((_) => _reset()))
      ..add(_auth.accountDeleted.listen((_) => _reset()));
    unawaited(sync());
  }

  /// Runs a sync if signed in and steps are allowed. Joins the one that is
  /// running, unless [force] is set or the session changed since it started: then
  /// one follow-up run waits for it. [force] skips the throttle (the
  /// **Refresh data** button). Never throws: failures are in [state].
  @override
  Future<void> sync({bool force = false}) {
    final queued = _followUp;
    if (queued != null) return queued;
    final running = _running;
    if (running == null) return _begin(force: force);
    if (!force && _runGeneration == _generation) return running;
    return _followUp = running.then((_) {
      _followUp = null;
      return _begin(force: true);
    });
  }

  Future<void> _begin({required bool force}) {
    _runGeneration = _generation;
    return _running = _run(
      force: force,
      generation: _generation,
    ).whenComplete(() => _running = null);
  }

  Future<void> _run({required bool force, required int generation}) async {
    bool stale() => generation != _generation;
    try {
      if (await _auth.restoreSession() == null || stale()) return;
      final access = await _health.checkAccess();
      if (stale()) return;
      if (!access.isGranted || !access.allowed.contains(HealthMetric.steps)) {
        return;
      }
      final last = _lastSuccessAt;
      if (!force &&
          last != null &&
          _clock().difference(last) < throttle &&
          setEquals(access.allowed, _lastAllowed)) {
        return;
      }
      _emit(
        HealthSyncState(
          busy: true,
          reading: _state.reading,
          syncedAt: _state.syncedAt,
        ),
      );
      try {
        final result = await _sync(access.allowed, clock: _clock);
        if (stale()) return;
        final failure = result.failure;
        if (failure == null) {
          _lastSuccessAt = _clock();
          _lastAllowed = access.allowed;
        }
        _emit(
          HealthSyncState(
            reading: result.reading,
            error: failure?.message,
            syncedAt: failure == null ? result.reading.readAt : _state.syncedAt,
          ),
        );
      } on HealthFailure catch (failure) {
        if (stale()) return;
        // Keep the figures on screen; say why they could not be updated.
        _emit(
          HealthSyncState(
            reading: _state.reading,
            error: failure.message,
            syncedAt: _state.syncedAt,
          ),
        );
      }
    } on Object catch (error, stack) {
      // A lifecycle callback has nobody to catch this.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      if (stale()) return;
      _emit(
        HealthSyncState(
          reading: _state.reading,
          error: const HealthFailure().message,
          syncedAt: _state.syncedAt,
        ),
      );
    }
  }

  void _reset() {
    _generation++;
    _lastSuccessAt = null;
    _lastAllowed = null;
    _emit(const HealthSyncState());
  }

  void _emit(HealthSyncState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  /// Stops listening. The service lives as long as the app; tests call this.
  @override
  @disposeMethod
  Future<void> dispose() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _controller.close();
  }
}
