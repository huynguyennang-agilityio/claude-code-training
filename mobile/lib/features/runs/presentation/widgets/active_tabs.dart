import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/activity_bloc.dart';
import '../bloc/my_challenges_bloc.dart';
import 'activity_tab.dart';
import 'my_challenges_tab.dart';

/// The Active page once health access is granted: the **Active** tab with the
/// day's figures, and **My Challenges**. Expects an [ActivityBloc] and a
/// [MyChallengesBloc].
///
/// The list is reloaded when a sync finishes (the backend has counted new
/// steps) and when the page is shown again (the user may have joined or paused
/// a challenge elsewhere).
class ActiveTabs extends StatefulWidget {
  const ActiveTabs({super.key});

  @override
  State<ActiveTabs> createState() => _ActiveTabsState();
}

class _ActiveTabsState extends State<ActiveTabs> {
  bool? _visible;

  /// A page that stays alive behind the other tabs is not rebuilt when it is
  /// opened again, but its tickers are switched back on.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (_visible == false && visible) {
      context.read<MyChallengesBloc>().add(const MyChallengesRefreshed());
    }
    _visible = visible;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActivityBloc, ActivityState>(
      listenWhen: (before, after) => before.busy && !after.busy,
      listener: (context, state) =>
          context.read<MyChallengesBloc>().add(const MyChallengesRefreshed()),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Active'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Active'),
                Tab(text: 'My Challenges'),
              ],
            ),
          ),
          body: const TabBarView(children: [ActivityTab(), MyChallengesTab()]),
        ),
      ),
    );
  }
}
