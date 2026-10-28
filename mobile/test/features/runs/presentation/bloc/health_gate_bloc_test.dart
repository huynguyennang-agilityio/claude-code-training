import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_gate_bloc.dart';

import '../../../../helpers/health_fixtures.dart';

const _granted = HealthAccess(
  HealthAccessStatus.granted,
  allowed: {HealthMetric.steps},
);

void main() {
  late FakeHealthRepository repository;

  setUp(() => repository = FakeHealthRepository(const HealthAccess.denied()));

  blocTest<HealthGateBloc, HealthGateState>(
    'starting checks access without asking',
    build: () => HealthGateBloc(repository),
    act: (bloc) => bloc.add(const HealthGateStarted()),
    expect: () => [const HealthGateResolved(HealthAccess.denied())],
    verify: (_) => expect((repository.checks, repository.requests), (1, 0)),
  );

  for (final access in [
    const HealthAccess.denied(),
    const HealthAccess.permanentlyDenied(),
    const HealthAccess.unavailable(),
    _granted,
  ]) {
    blocTest<HealthGateBloc, HealthGateState>(
      'starting with ${access.status.name} resolves to it',
      setUp: () => repository.access = access,
      build: () => HealthGateBloc(repository),
      act: (bloc) => bloc.add(const HealthGateStarted()),
      expect: () => [HealthGateResolved(access)],
    );
  }

  blocTest<HealthGateBloc, HealthGateState>(
    'allowing shows busy while the dialog is up, then granted',
    setUp: () => repository.afterRequest = _granted,
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.denied()),
    act: (bloc) => bloc.add(const HealthAccessRequested()),
    expect: () => [
      const HealthGateResolved(HealthAccess.denied(), busy: true),
      const HealthGateResolved(_granted),
    ],
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'refusing leaves the gate, and asking again is possible',
    setUp: () =>
        repository.afterRequest = const HealthAccess.permanentlyDenied(),
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.denied()),
    act: (bloc) => bloc.add(const HealthAccessRequested()),
    expect: () => [
      const HealthGateResolved(HealthAccess.denied(), busy: true),
      const HealthGateResolved(HealthAccess.permanentlyDenied()),
    ],
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'a request while one is running, or before access is known, is ignored',
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.denied(), busy: true),
    act: (bloc) => bloc
      ..add(const HealthAccessRequested())
      ..add(const HealthAccessRequested()),
    expect: () => <HealthGateState>[],
    verify: (_) => expect(repository.requests, 0),
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'a request while still checking is ignored',
    build: () => HealthGateBloc(repository),
    act: (bloc) => bloc.add(const HealthAccessRequested()),
    expect: () => <HealthGateState>[],
    verify: (_) => expect(repository.requests, 0),
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'rechecking updates the state without a spinner, e.g. after Settings',
    setUp: () => repository.access = _granted,
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.permanentlyDenied()),
    act: (bloc) => bloc.add(const HealthGateRechecked()),
    expect: () => [const HealthGateResolved(_granted)],
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'rechecking finds access that was turned off',
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(_granted),
    act: (bloc) => bloc.add(const HealthGateRechecked()),
    expect: () => [const HealthGateResolved(HealthAccess.denied())],
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'rechecking does not disturb a request in progress',
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.denied(), busy: true),
    act: (bloc) => bloc.add(const HealthGateRechecked()),
    expect: () => <HealthGateState>[],
    verify: (_) => expect(repository.checks, 0),
  );

  blocTest<HealthGateBloc, HealthGateState>(
    'Open settings and Install go to the repository and change nothing',
    build: () => HealthGateBloc(repository),
    seed: () => const HealthGateResolved(HealthAccess.permanentlyDenied()),
    act: (bloc) => bloc
      ..add(const HealthSettingsRequested())
      ..add(const HealthInstallRequested()),
    expect: () => <HealthGateState>[],
    verify: (_) =>
        expect((repository.settingsOpened, repository.installs), (1, 1)),
  );
}
