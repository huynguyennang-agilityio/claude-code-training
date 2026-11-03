import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/health_access.dart';
import '../bloc/activity_bloc.dart';
import '../bloc/health_gate_bloc.dart';
import '../bloc/health_notice_bloc.dart';
import '../bloc/my_challenges_bloc.dart';
import '../widgets/active_tabs.dart';
import '../widgets/activity_tab.dart';
import '../widgets/health_gate_view.dart';

/// The Active page: the **Active** tab and **My Challenges**. My Challenges
/// always opens; the Active tab shows the health gate in place of the figures
/// until steps may be read. Expects a [HealthGateBloc] and a
/// [HealthNoticeBloc].
class ActiveChallengesPage extends StatefulWidget {
  const ActiveChallengesPage({super.key});

  static const path = '/active';

  @override
  State<ActiveChallengesPage> createState() => _ActiveChallengesPageState();
}

class _ActiveChallengesPageState extends State<ActiveChallengesPage>
    with WidgetsBindingObserver {
  bool? _visible;

  /// Keeps the tabs, and the tab the user is on, when access changes and the
  /// tabs move under the figures' bloc.
  final _tabs = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user comes back from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  /// A tab that stays alive behind the others is not rebuilt when it is opened
  /// again, but its tickers are switched back on: that is the moment to check
  /// access once more.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (_visible == false && visible) _recheck();
    _visible = visible;
  }

  void _recheck() {
    if (!mounted) return;
    context.read<HealthGateBloc>().add(const HealthGateRechecked());
  }

  @override
  Widget build(BuildContext context) {
    // One list bloc for the page, whatever health access does: the list does
    // not reload when access changes.
    return BlocProvider(
      create: (_) =>
          getIt<MyChallengesBloc>()..add(const MyChallengesStarted()),
      child: MultiBlocListener(
        listeners: [
          // Access granted from the gate: the notice above the list follows.
          BlocListener<HealthGateBloc, HealthGateState>(
            listenWhen: (before, after) =>
                before is HealthGateResolved &&
                after is HealthGateResolved &&
                !after.busy &&
                before.access != after.access,
            listener: (context, state) => context.read<HealthNoticeBloc>().add(
              const HealthNoticeRefreshed(),
            ),
          ),
          // Access asked from the notice: the Active tab follows.
          BlocListener<HealthNoticeBloc, HealthNoticeState>(
            listenWhen: (before, after) => before.busy && !after.busy,
            listener: (context, state) => _recheck(),
          ),
        ],
        child: BlocBuilder<HealthGateBloc, HealthGateState>(
          builder: (context, state) => switch (state) {
            HealthGateChecking() => ActiveTabs(
              key: _tabs,
              activity: const Center(child: CircularProgressIndicator()),
            ),
            HealthGateResolved(access: final access) when access.isGranted =>
              MultiBlocProvider(
                // A new bloc when the allowed metrics change (turned on in
                // Settings).
                key: ValueKey(access.allowed),
                providers: [
                  BlocProvider(
                    create: (_) =>
                        getIt<ActivityBloc>()
                          ..add(ActivityStarted(access.allowed)),
                  ),
                ],
                child: _SyncRefreshesList(
                  child: ActiveTabs(key: _tabs, activity: const ActivityTab()),
                ),
              ),
            HealthGateResolved(:final access, :final busy) => ActiveTabs(
              key: _tabs,
              activity: HealthGateView(
                status: access.status,
                busy: busy,
                onAction: () =>
                    context.read<HealthGateBloc>().add(switch (access.status) {
                      HealthAccessStatus.permanentlyDenied =>
                        const HealthSettingsRequested(),
                      HealthAccessStatus.unavailable =>
                        const HealthInstallRequested(),
                      _ => const HealthAccessRequested(),
                    }),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Reloads My Challenges when a sync finishes: the backend has counted new
/// steps. Expects an [ActivityBloc] and a [MyChallengesBloc].
class _SyncRefreshesList extends StatelessWidget {
  const _SyncRefreshesList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActivityBloc, ActivityState>(
      listenWhen: (before, after) => before.busy && !after.busy,
      listener: (context, state) =>
          context.read<MyChallengesBloc>().add(const MyChallengesRefreshed()),
      child: child,
    );
  }
}
