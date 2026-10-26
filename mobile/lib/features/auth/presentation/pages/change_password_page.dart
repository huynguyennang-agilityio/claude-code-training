import 'package:flutter/material.dart';

/// Placeholder for the Password form, replaced by its own task. It is pushed
/// above the tab bar, so the app bar's back button returns to the tab.
class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  static const path = '/profile/password';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
