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
  }

  final GetHealthNotice _getNotice;
  final HealthRepository _health;
  final HealthSync _sync;

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
    emit(HealthNoticeState(notice: state.notice, busy: true));
    try {
      final access = await _health.requestAccess();
      if (access.isGranted && access.allowed.contains(HealthMetric.steps)) {
        // Sync at once; the banner need not wait for the figures to arrive.
        // The sync never throws and reports its own failures in its state.
        unawaited(_sync.syncNow());
      }
    } on Object catch (error, stack) {
      _report(error, stack);
    }
    emit(HealthNoticeState(notice: await _notice()));
  }

  Future<void> _evaluate(Emitter<HealthNoticeState> emit) async =>
      emit(HealthNoticeState(notice: await _notice()));

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
