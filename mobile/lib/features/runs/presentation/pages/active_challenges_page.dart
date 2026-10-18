import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/tab_placeholder.dart';
import '../../domain/entities/health_access.dart';
import '../bloc/health_gate_bloc.dart';
import '../widgets/health_gate_view.dart';

/// The Active tab. It opens only when steps may be read: until then it shows the
/// health gate. Expects a [HealthGateBloc].
class ActiveChallengesPage extends StatefulWidget {
  const ActiveChallengesPage({super.key});

  static const path = '/active';

  @override
  State<ActiveChallengesPage> createState() => _ActiveChallengesPageState();
}

class _ActiveChallengesPageState extends State<ActiveChallengesPage>
    with WidgetsBindingObserver {
  bool? _visible;

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
    return BlocBuilder<HealthGateBloc, HealthGateState>(
      builder: (context, state) => switch (state) {
        HealthGateChecking() => Scaffold(
          appBar: AppBar(title: const Text('Active')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        HealthGateResolved(access: final access) when access.isGranted =>
          const TabPlaceholder(
            title: 'Active',
            message:
                'The challenges you are doing, and your progress, will show '
                'up here.',
          ),
        HealthGateResolved(:final access, :final busy) => HealthGateView(
          status: access.status,
          busy: busy,
          onAction: () => context.read<HealthGateBloc>().add(
            switch (access.status) {
              HealthAccessStatus.permanentlyDenied =>
                const HealthSettingsRequested(),
              HealthAccessStatus.unavailable => const HealthInstallRequested(),
              _ => const HealthAccessRequested(),
            },
          ),
        ),
      },
    );
  }
}
