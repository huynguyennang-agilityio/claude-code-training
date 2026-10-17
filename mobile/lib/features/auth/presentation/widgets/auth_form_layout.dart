import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// The frame shared by the sign-in and sign-up screens: an app bar (with a back
/// button when [onBack] is given), a heading and a line of text, the [children] (banner and fields),
/// then the [actions] (button and link) at the bottom of the screen. The
/// content scrolls, so the keyboard and large text never overflow.
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    super.key,
    required this.title,
    required this.heading,
    required this.subtitle,
    required this.children,
    required this.actions,
    this.onBack,
  });

  final String title;
  final String heading;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  /// What the back button does. Null for a screen with nowhere to go back to:
  /// there is no back button then.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Text(heading, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ...children,
                        const SizedBox(height: AppSpacing.lg),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
