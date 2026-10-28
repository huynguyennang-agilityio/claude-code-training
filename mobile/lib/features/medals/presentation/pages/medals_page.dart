import 'package:flutter/widgets.dart';

import '../../../../shared/widgets/tab_placeholder.dart';

/// The Medals tab: medals earned and still locked. A placeholder until it is
/// built.
class MedalsPage extends StatelessWidget {
  const MedalsPage({super.key});

  static const path = '/medals';

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Medals',
      message: 'The medals you earn will show up here.',
    );
  }
}
