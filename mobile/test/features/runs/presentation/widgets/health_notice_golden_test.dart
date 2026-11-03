import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_notice_banner.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_sheets.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/health_fixtures.dart';

Widget _page(HealthNotice notice, TargetPlatform platform) {
  final bloc = MockHealthNoticeBloc();
  whenListen(
    bloc,
    const Stream<HealthNoticeState>.empty(),
    initialState: HealthNoticeState(notice: notice),
  );
  return Scaffold(
    body: SafeArea(
      child: BlocProvider<HealthNoticeBloc>.value(
        value: bloc,
        child: HealthNoticeBanner(platform: platform),
      ),
    ),
  );
}

/// A sheet at the bottom of the screen, as the modal route shows it.
Widget _sheet(Widget sheet) => Scaffold(
  body: Align(
    alignment: Alignment.bottomCenter,
    child: Material(child: sheet),
  ),
);

void main() {
  goldenScreen(
    'HealthNoticeBanner, askable on iOS',
    'health_notice_banner_askable_ios',
    _page(HealthNotice.askable, TargetPlatform.iOS),
  );
  goldenScreen(
    'HealthNoticeBanner, askable on Android',
    'health_notice_banner_askable_android',
    _page(HealthNotice.askable, TargetPlatform.android),
  );
  goldenScreen(
    'HealthNoticeBanner, install',
    'health_notice_banner_install',
    _page(HealthNotice.install, TargetPlatform.android),
  );
  goldenScreen(
    'HealthNoticeBanner, no steps',
    'health_notice_banner_no_steps',
    _page(HealthNotice.noSteps, TargetPlatform.iOS),
  );
  goldenScreen(
    'HealthExplainerSheet',
    'health_explainer_sheet',
    _sheet(const HealthExplainerSheet()),
  );
  goldenScreen(
    'HealthSettingsSheet',
    'health_settings_sheet',
    _sheet(const HealthSettingsSheet()),
  );
}
