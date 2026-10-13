import 'package:flutter/material.dart';

import 'ui/router.dart';

class StrideQuestApp extends StatelessWidget {
  const StrideQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StrideQuest',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      routerConfig: appRouter,
    );
  }
}
