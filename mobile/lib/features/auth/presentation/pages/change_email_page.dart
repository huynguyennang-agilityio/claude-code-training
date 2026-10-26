import 'package:flutter/material.dart';

/// Placeholder for the Email form, replaced by its own task. It is pushed
/// above the tab bar, so the app bar's back button returns to the tab.
class ChangeEmailPage extends StatelessWidget {
  const ChangeEmailPage({super.key});

  static const path = '/profile/email';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
