import 'package:flutter/material.dart';

/// Placeholder for the Profile info form, replaced by its own task. It is
/// pushed above the tab bar, so the app bar's back button returns to the tab.
class ProfileInfoPage extends StatelessWidget {
  const ProfileInfoPage({super.key});

  static const path = '/profile/info';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
