import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/activity.dart';
import '../domain/entities/health_access.dart';
import '../domain/failures/runs_failure.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/usecases/sync_activity.dart';

/// What the screens show of the health sync.
class HealthSyncState extends Equatable {
  const HealthSyncState({
    this.busy = false,
    this.reading,
    this.error,
    this.syncedAt,
  });

  /// A sync is running.
  final bool busy;

  /// Today's figures from the last sync that read them; null before the first.
  final ActivityReading? reading;

  /// What went wrong in the last sync, or null.
  final String? error;

  /// When the figures last reached StrideQuest.
  final DateTime? syncedAt;

  @override
  List<Object?> get props => [busy, reading, error, syncedAt];
}

/// Syncs the health data when the app opens, comes back to the foreground and
/// when a session starts, so the Active tab is not the only way data reaches the
/// backend. One app-wide service (not a bloc): screens read [state] and [stream].
///
/// A sync runs only when someone is signed in and steps may be read. Two
/// triggers at once share one run (single-flight). A trigger within [throttle]
/// of the end of the last successful sync does nothing, unless it is forced.
/// A run that threw a `HealthFailure` or returned a `RunsFailure` does not
/// start the throttle, so the next trigger retries.
@lazySingleton
class HealthSyncService {
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
  DateTime? _lastSuccessAt;
  HealthSyncState _state = const HealthSyncState();

  /// The latest state; it never goes back to empty while the app runs, except
  /// when the session ends.
  HealthSyncState get state => _state;

  /// Every change of [state].
  Stream<HealthSyncState> get stream => _controller.stream;

  /// Listens for resume and for new or ended sessions, and runs the cold-start
  /// sync. Call once, after the dependencies are set up.
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
  /// running. [force] skips the throttle (the **Refresh data** button). Never
  /// throws: failures are in [state].
  Future<void> sync({bool force = false}) {
    final running = _running;
    if (running != null) return running;
    final now = _clock();
    final last = _lastSuccessAt;
    if (!force && last != null && now.difference(last) < throttle) {
      return Future.value();
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    try {
      if (await _auth.restoreSession() == null) return;
      final access = await _health.checkAccess();
      if (!access.isGranted || !access.allowed.contains(HealthMetric.steps)) {
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
        final failure = result.failure;
        if (failure == null) _lastSuccessAt = _clock();
        _emit(
          HealthSyncState(
            reading: result.reading,
            error: failure?.message,
            syncedAt: failure == null ? result.reading.readAt : _state.syncedAt,
          ),
        );
      } on HealthFailure catch (failure) {
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
      if (_state.busy) _emit(HealthSyncState(reading: _state.reading));
    }
  }

  void _reset() {
    _lastSuccessAt = null;
    _emit(const HealthSyncState());
  }

  void _emit(HealthSyncState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  /// Stops listening. The service lives as long as the app; tests call this.
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
