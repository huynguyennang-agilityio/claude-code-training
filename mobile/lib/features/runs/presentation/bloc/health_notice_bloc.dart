import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/health_access.dart';
import '../../domain/repositories/health_repository.dart';
import '../../domain/services/health_sync.dart';
import '../../domain/usecases/get_health_notice.dart';

part 'health_notice_event.dart';
part 'health_notice_state.dart';

/// The reminder about health access, shown above a screen's content. A factory
/// bloc created in the route's `BlocProvider`, which adds [HealthNoticeStarted].
/// It never blocks anything: when the notice cannot be worked out, none shows.
@injectable
class HealthNoticeBloc extends Bloc<HealthNoticeEvent, HealthNoticeState> {
  HealthNoticeBloc(this._getNotice, this._health, this._sync)
    : super(const HealthNoticeState()) {
    on<HealthNoticeStarted>((event, emit) => _evaluate(emit));
    on<HealthNoticeRefreshed>(_onRefreshed);
    on<HealthNoticeAccessRequested>(_onRequested);
    on<HealthNoticeSettingsRequested>(
      (event, emit) => _guard(_health.openSettings),
    );
    on<HealthNoticeInstallRequested>(
      (event, emit) => _guard(_health.installHealthConnect),
    );
    on<HealthNoticeJoinPrompted>(_onJoinPrompted);
    on<HealthNoticeExplainerShown>(_onExplainerShown);
    on<HealthNoticeExplainerSkipped>((event, emit) => _prompting = false);
  }

  final GetHealthNotice _getNotice;
  final HealthRepository _health;
  final HealthSync _sync;

  /// Bumped by each check; a check whose number is no longer the latest drops
  /// its result. Events run concurrently, so a check started before the user
  /// asked could otherwise finish after the answer and show a stale notice.
  int _check = 0;

  /// True from a join prompt until the screen answers its signal with
  /// [HealthNoticeExplainerShown] or [HealthNoticeExplainerSkipped], so two
  /// joins in a row ask once.
  bool _prompting = false;

  Future<void> _onJoinPrompted(
    HealthNoticeJoinPrompted event,
    Emitter<HealthNoticeState> emit,
  ) async {
    if (_prompting) return;
    _prompting = true;
    var signalled = false;
    try {
      final askable = await _getNotice() == HealthNotice.askable;
      if (askable && await _health.explainerDue()) {
        signalled = true;
        emit(state.copyWith(explainerCount: state.explainerCount + 1));
      }
    } on Object catch (error, stack) {
      _report(error, stack);
    } finally {
      // Without a signal nobody will answer, so the flag clears here.
      if (!signalled) _prompting = false;
    }
  }

  Future<void> _onExplainerShown(
    HealthNoticeExplainerShown event,
    Emitter<HealthNoticeState> emit,
  ) async {
    _prompting = false;
    await _guard(_health.recordExplainerShown);
  }

  Future<void> _onRefreshed(
    HealthNoticeRefreshed event,
    Emitter<HealthNoticeState> emit,
  ) async {
    // The system dialog is up: its answer decides, not this check.
    if (state.busy) return;
    await _evaluate(emit);
  }

  Future<void> _onRequested(
    HealthNoticeAccessRequested event,
    Emitter<HealthNoticeState> emit,
  ) async {
    if (state.busy) return;
    _check++;
    emit(state.copyWith(busy: true));
    try {
      final access = await _health.requestAccess();
      if (access.canReadSteps) {
        // Sync at once; the banner need not wait for the figures to arrive.
        // The sync never throws and reports its own failures in its state.
        unawaited(_sync.syncNow());
      }
    } on Object catch (error, stack) {
      _report(error, stack);
    }
    final check = ++_check;
    final notice = await _notice();
    if (check == _check) emit(state.copyWith(notice: notice, busy: false));
  }

  Future<void> _evaluate(Emitter<HealthNoticeState> emit) async {
    final check = ++_check;
    final notice = await _notice();
    if (check != _check) return;
    emit(state.copyWith(notice: notice));
  }

  /// The current notice; the previous one stays when it cannot be worked out.
  Future<HealthNotice> _notice() async {
    try {
      return await _getNotice();
    } on Object catch (error, stack) {
      _report(error, stack);
      return state.notice;
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack),
  );
}
