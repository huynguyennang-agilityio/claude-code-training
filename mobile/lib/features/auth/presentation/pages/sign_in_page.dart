import 'package:flutter/material.dart';

/// Placeholder target for the router's sign-in redirect.
///
/// The real sign-in form needs its own issue with a design reference
/// (CLAUDE.md ticket evidence gate).
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  static const path = '/sign-in';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: const Center(child: Text('Sign in to continue.')),
    );
  }
}
