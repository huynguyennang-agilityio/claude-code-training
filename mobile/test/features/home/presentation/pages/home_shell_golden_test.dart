import 'package:flutter/material.dart';
import 'package:stridequest/features/home/presentation/pages/home_shell.dart';

import '../../../../helpers/golden_screen.dart';

void main() {
  for (var selected = 0; selected < HomeShell.tabs.length; selected++) {
    final label = HomeShell.tabs[selected].label;
    goldenScreen(
      'HomeScaffold, $label selected',
      'home_scaffold_${label.toLowerCase()}',
      HomeScaffold(
        body: const SizedBox.expand(),
        selectedIndex: selected,
        onSelected: (_) {},
      ),
    );
  }
}
