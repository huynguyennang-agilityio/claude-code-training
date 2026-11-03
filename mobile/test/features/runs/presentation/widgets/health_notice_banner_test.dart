import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_notice_banner.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_sheets.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/pump_screen.dart';

Widget banner(
  MockHealthNoticeBloc bloc, {
  TargetPlatform platform = TargetPlatform.iOS,
}) => BlocProvider<HealthNoticeBloc>.value(
  value: bloc,
  child: Scaffold(body: HealthNoticeBanner(platform: platform)),
);

MockHealthNoticeBloc blocWith(HealthNotice notice) {
  final bloc = MockHealthNoticeBloc();
  whenListen(
    bloc,
    const Stream<HealthNoticeState>.empty(),
    initialState: HealthNoticeState(notice: notice),
  );
  return bloc;
}

void main() {
  setUpAll(() => registerFallbackValue(const HealthNoticeStarted()));

  testWidgets('shows nothing when there is no notice', (tester) async {
    await pumpScreen(tester, banner(blocWith(HealthNotice.none)));
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  const texts = {
    HealthNotice.askable: "Steps aren't tracked yet. Turn on Apple Health",
    HealthNotice.settings: "Steps aren't tracked yet. Turn on Apple Health",
    HealthNotice.install: 'Install Health Connect to track your steps',
    HealthNotice.noSteps:
        'No steps from Apple Health. Check access in Settings',
  };
  for (final entry in texts.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${entry.key} on iOS at text x$scale', (tester) async {
        await pumpScreen(tester, banner(blocWith(entry.key)), textScale: scale);
        expect(find.text(entry.value), findsOneWidget);
        expectNoLayoutException(tester);
        await expectAccessible(tester);
      });
    }
  }

  testWidgets('Android names Health Connect', (tester) async {
    await pumpScreen(
      tester,
      banner(blocWith(HealthNotice.askable), platform: TargetPlatform.android),
    );
    expect(
      find.text("Steps aren't tracked yet. Turn on Health Connect"),
      findsOneWidget,
    );
    await pumpScreen(
      tester,
      banner(blocWith(HealthNotice.noSteps), platform: TargetPlatform.android),
    );
    expect(
      find.text('No steps from Health Connect. Check access in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('follows the running platform when none is given', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pumpScreen(
      tester,
      BlocProvider<HealthNoticeBloc>.value(
        value: blocWith(HealthNotice.settings),
        child: const Scaffold(body: HealthNoticeBanner()),
      ),
    );
    expect(find.textContaining('Health Connect'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('askable opens the explainer; Continue asks for access', (
    tester,
  ) async {
    final bloc = blocWith(HealthNotice.askable);
    await pumpScreen(tester, banner(bloc));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.byType(HealthExplainerSheet), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthExplainerSheet), findsNothing);
    verify(() => bloc.add(const HealthNoticeAccessRequested())).called(1);
  });

  testWidgets('Not now closes the explainer and asks for nothing', (
    tester,
  ) async {
    final bloc = blocWith(HealthNotice.askable);
    await pumpScreen(tester, banner(bloc));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthExplainerSheet), findsNothing);
    verifyNever(() => bloc.add(any()));
  });

  for (final notice in [HealthNotice.settings, HealthNotice.noSteps]) {
    testWidgets('$notice opens the settings sheet; Open settings acts', (
      tester,
    ) async {
      final bloc = blocWith(notice);
      await pumpScreen(tester, banner(bloc));
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(HealthSettingsSheet), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const HealthNoticeSettingsRequested())).called(1);
    });
  }

  testWidgets('install goes straight to the store', (tester) async {
    final bloc = blocWith(HealthNotice.install);
    await pumpScreen(tester, banner(bloc));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.byType(HealthSettingsSheet), findsNothing);
    verify(() => bloc.add(const HealthNoticeInstallRequested())).called(1);
  });

  testWidgets('checks again when the app resumes', (tester) async {
    final bloc = blocWith(HealthNotice.settings);
    await pumpScreen(tester, banner(bloc));
    verifyNever(() => bloc.add(any()));

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    verify(() => bloc.add(const HealthNoticeRefreshed())).called(1);
  });

  testWidgets('stops listening for resume once removed', (tester) async {
    final bloc = blocWith(HealthNotice.settings);
    await pumpScreen(tester, banner(bloc));
    await tester.pumpWidget(const SizedBox());
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('the busy banner ignores taps', (tester) async {
    final bloc = MockHealthNoticeBloc();
    whenListen(
      bloc,
      const Stream<HealthNoticeState>.empty(),
      initialState: const HealthNoticeState(
        notice: HealthNotice.askable,
        busy: true,
      ),
    );
    await pumpScreen(tester, banner(bloc));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.byType(HealthExplainerSheet), findsNothing);
  });
}
