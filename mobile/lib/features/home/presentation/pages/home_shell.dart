import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../challenges/presentation/pages/active_challenges_page.dart';
import '../../../challenges/presentation/pages/challenges_page.dart';
import '../../../medals/presentation/pages/medals_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

/// The signed-in shell: the current tab above a bottom bar with the four tabs.
/// Each tab keeps its own state and back stack ([navigationShell]).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  /// `/` has no screen of its own: it redirects to the first tab.
  static const path = '/';

  /// The tabs, in the order of the shell's branches.
  static const tabs = <HomeTab>[
    HomeTab('Challenges', Icons.explore_outlined, ChallengesPage.path),
    HomeTab('Active', Icons.directions_run, ActiveChallengesPage.path),
    HomeTab('Medals', Icons.workspace_premium_outlined, MedalsPage.path),
    HomeTab('Profile', Icons.person_outline, ProfilePage.path),
  ];

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthBloc, bool>(
      (bloc) => bloc.state is AuthAuthenticated,
    );
    // The shell is for signed-in users. Until the stored session is read, or
    // while the router redirect to sign in runs, show progress instead of
    // content a signed-out user must not see.
    if (!signedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeScaffold(
      selectedIndex: navigationShell.currentIndex,
      // Tapping the selected tab again returns to the tab's first page.
      onSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      body: navigationShell,
    );
  }
}

/// The [body] above the bottom bar of the four [HomeShell.tabs]. It knows
/// nothing about routing, so it can be tested and drawn on its own.
class HomeScaffold extends StatelessWidget {
  const HomeScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outline)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: [
            for (final tab in HomeShell.tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      ),
    );
  }
}

/// One tab of the bottom bar.
class HomeTab {
  const HomeTab(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}
