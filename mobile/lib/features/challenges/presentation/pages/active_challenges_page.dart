import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/tab_placeholder.dart';

/// The Active tab: the challenges the user is doing, with progress. A
/// placeholder until it is built.
class ActiveChallengesPage extends StatelessWidget {
  const ActiveChallengesPage({super.key});

  static const path = '/active';

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Active',
      message:
          'The challenges you are doing, and your progress, will show up '
          'here.',
    );
  }
}
