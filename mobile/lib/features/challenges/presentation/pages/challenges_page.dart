import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/tab_placeholder.dart';

/// The Challenges tab: browse the available quests. A placeholder until the
/// list is built.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  static const path = '/challenges';

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Challenges',
      message: 'Running quests you can take on will show up here.',
    );
  }
}
