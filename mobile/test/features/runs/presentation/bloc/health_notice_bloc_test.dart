import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';
import 'package:stridequest/features/runs/domain/usecases/get_health_notice.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';

class _MockGetNotice extends Mock implements GetHealthNotice {}

class _MockHealth extends Mock implements HealthRepository {}

class _MockSync extends Mock implements HealthSync {}

const _granted = HealthAccess(
  HealthAccessStatus.granted,
  allowed: {HealthMetric.steps},
);

void main() {
  late _MockGetNotice getNotice;
  late _MockHealth health;
  late _MockSync sync;

  late FlutterExceptionHandler? onError;
  final reported = <Object>[];

  setUp(() {
    // The bloc reports failures it swallows; collect them instead of printing.
    onError = FlutterError.onError;
    reported.clear();
    FlutterError.onError = (details) => reported.add(details.exception);
    getNotice = _MockGetNotice();
    health = _MockHealth();
    sync = _MockSync();
    when(() => getNotice()).thenAnswer((_) async => HealthNotice.askable);
    when(() => sync.syncNow()).thenAnswer((_) async {});
    when(health.openSettings).thenAnswer((_) async {});
    when(health.installHealthConnect).thenAnswer((_) async {});
  });

  tearDown(() => FlutterError.onError = onError);

  HealthNoticeBloc build() => HealthNoticeBloc(getNotice, health, sync);

  test('starts with no notice', () {
    expect(build().state, const HealthNoticeState());
  });

  for (final notice in HealthNotice.values.where(
    (n) => n != HealthNotice.none,
  )) {
    blocTest<HealthNoticeBloc, HealthNoticeState>(
      'started shows $notice',
      setUp: () => when(() => getNotice()).thenAnswer((_) async => notice),
      build: build,
      act: (bloc) => bloc.add(const HealthNoticeStarted()),
      expect: () => [HealthNoticeState(notice: notice)],
    );
  }

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'started with nothing to say shows none',
    setUp: () =>
        when(() => getNotice()).thenAnswer((_) async => HealthNotice.none),
    build: build,
    act: (bloc) => bloc.add(const HealthNoticeStarted()),
    expect: () => [const HealthNoticeState()],
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'refreshed checks again and hides the notice once fixed',
    build: build,
    seed: () => const HealthNoticeState(notice: HealthNotice.settings),
    setUp: () =>
        when(() => getNotice()).thenAnswer((_) async => HealthNotice.none),
    act: (bloc) => bloc.add(const HealthNoticeRefreshed()),
    expect: () => [const HealthNoticeState()],
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'a notice that cannot be worked out keeps the previous one',
    build: build,
    seed: () => const HealthNoticeState(notice: HealthNotice.settings),
    setUp: () => when(() => getNotice()).thenThrow(const HealthFailure()),
    act: (bloc) => bloc.add(const HealthNoticeRefreshed()),
    expect: () => <HealthNoticeState>[],
    errors: () => <Matcher>[],
    verify: (_) {
      verify(() => getNotice()).called(1);
      expect(reported, [isA<HealthFailure>()]);
    },
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'access granted: syncs at once and the notice goes away',
    build: build,
    seed: () => const HealthNoticeState(notice: HealthNotice.askable),
    setUp: () {
      when(health.requestAccess).thenAnswer((_) async => _granted);
      when(() => getNotice()).thenAnswer((_) async => HealthNotice.none);
    },
    act: (bloc) => bloc.add(const HealthNoticeAccessRequested()),
    expect: () => [
      const HealthNoticeState(notice: HealthNotice.askable, busy: true),
      const HealthNoticeState(),
    ],
    verify: (_) {
      verify(health.requestAccess).called(1);
      verify(() => sync.syncNow()).called(1);
    },
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'access refused for good: no sync, the notice moves to settings',
    build: build,
    seed: () => const HealthNoticeState(notice: HealthNotice.askable),
    setUp: () {
      when(
        health.requestAccess,
      ).thenAnswer((_) async => const HealthAccess.permanentlyDenied());
      when(() => getNotice()).thenAnswer((_) async => HealthNotice.settings);
    },
    act: (bloc) => bloc.add(const HealthNoticeAccessRequested()),
    expect: () => [
      const HealthNoticeState(notice: HealthNotice.askable, busy: true),
      const HealthNoticeState(notice: HealthNotice.settings),
    ],
    verify: (_) => verifyNever(() => sync.syncNow()),
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'granted without steps does not sync',
    build: build,
    setUp: () {
      when(health.requestAccess).thenAnswer(
        (_) async => const HealthAccess(
          HealthAccessStatus.granted,
          allowed: {HealthMetric.sleep},
        ),
      );
    },
    act: (bloc) => bloc.add(const HealthNoticeAccessRequested()),
    verify: (_) => verifyNever(() => sync.syncNow()),
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'a request that fails ends the wait and checks again',
    build: build,
    seed: () => const HealthNoticeState(notice: HealthNotice.askable),
    setUp: () => when(health.requestAccess).thenThrow(const HealthFailure()),
    act: (bloc) => bloc.add(const HealthNoticeAccessRequested()),
    expect: () => [
      const HealthNoticeState(notice: HealthNotice.askable, busy: true),
      const HealthNoticeState(notice: HealthNotice.askable),
    ],
    verify: (_) {
      verifyNever(() => sync.syncNow());
      expect(reported, [isA<HealthFailure>()]);
    },
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'refresh while the dialog is up is ignored',
    build: build,
    seed: () =>
        const HealthNoticeState(notice: HealthNotice.askable, busy: true),
    act: (bloc) => bloc.add(const HealthNoticeRefreshed()),
    expect: () => <HealthNoticeState>[],
    verify: (_) => verifyNever(() => getNotice()),
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'open settings',
    build: build,
    act: (bloc) => bloc.add(const HealthNoticeSettingsRequested()),
    verify: (_) => verify(health.openSettings).called(1),
  );

  blocTest<HealthNoticeBloc, HealthNoticeState>(
    'install Health Connect',
    build: build,
    act: (bloc) => bloc.add(const HealthNoticeInstallRequested()),
    verify: (_) => verify(health.installHealthConnect).called(1),
  );
}
