import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/health_notice_bloc.dart';
import '../bloc/my_challenges_bloc.dart';
import 'health_notice_banner.dart';
import 'my_challenges_tab.dart';

/// The two tabs of the Active page: **Active**, showing [activity] (the day's
/// figures, the health gate or a spinner), and **My Challenges**, with the
/// health notice above the list. Expects a [MyChallengesBloc] and a
/// [HealthNoticeBloc].
///
/// The list is reloaded when the page is shown again (the user may have joined
/// or paused a challenge elsewhere).
class ActiveTabs extends StatefulWidget {
  const ActiveTabs({super.key, required this.activity, this.initialIndex = 0});

  /// The content of the Active tab.
  final Widget activity;

  /// The tab shown first: 0 is Active, 1 is My Challenges.
  final int initialIndex;

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
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
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
        body: TabBarView(
          children: [
            widget.activity,
            const Column(
              children: [
                HealthNoticeBanner(),
                Expanded(child: MyChallengesTab()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
