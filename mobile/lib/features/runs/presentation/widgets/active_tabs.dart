import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import 'activity_tab.dart';

/// The Active page once health access is granted: the **Active** tab with the
/// day's figures, and **My Challenges** (built in the next step). Expects an
/// `ActivityBloc`.
class ActiveTabs extends StatelessWidget {
  const ActiveTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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
        body: const TabBarView(children: [ActivityTab(), _MyChallengesSoon()]),
      ),
    );
  }
}

/// Until the list of joined challenges is built.
class _MyChallengesSoon extends StatelessWidget {
  const _MyChallengesSoon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'The challenges you have joined, with your progress, show up here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
