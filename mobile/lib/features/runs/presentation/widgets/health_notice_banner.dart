import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/health_access.dart';
import '../bloc/health_notice_bloc.dart';
import 'health_sheets.dart';

/// The one line that tells the user steps are not tracked, with the action
/// that fixes it. Shows nothing when there is nothing to fix. Reads the
/// [HealthNoticeBloc] above it, and checks again when the app resumes (the user
/// may have just changed the setting).
class HealthNoticeBanner extends StatefulWidget {
  const HealthNoticeBanner({super.key, this.platform});

  /// The platform that picks the app's name in the text; the running platform
  /// when null. A test sets it.
  final TargetPlatform? platform;

  @override
  State<HealthNoticeBanner> createState() => _HealthNoticeBannerState();
}

class _HealthNoticeBannerState extends State<HealthNoticeBanner> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          context.read<HealthNoticeBloc>().add(const HealthNoticeRefreshed()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// The name of the platform's health app.
  String get _healthApp =>
      (widget.platform ?? defaultTargetPlatform) == TargetPlatform.android
      ? 'Health Connect'
      : 'Apple Health';

  String _text(HealthNotice notice) => switch (notice) {
    HealthNotice.askable ||
    HealthNotice.settings => "Steps aren't tracked yet. Turn on $_healthApp",
    HealthNotice.install => 'Install Health Connect to track your steps',
    HealthNotice.noSteps =>
      'No steps from $_healthApp. Check access in Settings',
    HealthNotice.none => '',
  };

  Future<void> _onTap(HealthNotice notice) async {
    final bloc = context.read<HealthNoticeBloc>();
    switch (notice) {
      case HealthNotice.askable:
        // Use only the bloc after the sheet: the route, and its bloc, may
        // have closed while the sheet was up.
        final accepted = await showHealthExplainer(context);
        if (accepted && !bloc.isClosed) {
          bloc.add(const HealthNoticeAccessRequested());
        }
      case HealthNotice.settings || HealthNotice.noSteps:
        final accepted = await showHealthSettings(context);
        if (accepted && !bloc.isClosed) {
          bloc.add(const HealthNoticeSettingsRequested());
        }
      case HealthNotice.install:
        bloc.add(const HealthNoticeInstallRequested());
      case HealthNotice.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthNoticeBloc, HealthNoticeState>(
      builder: (context, state) {
        if (state.notice == HealthNotice.none) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: state.busy ? null : () => _onTap(state.notice),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.favorite_border,
                          size: AppActiveSizes.tileIcon,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _text(state.notice),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
