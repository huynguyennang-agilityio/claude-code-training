import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../home/presentation/pages/home_page.dart';

/// The frame shared by the sign-in and sign-up screens: an app bar with a back
/// button, a heading and a line of text, the [children] (banner and fields),
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
  });

  final String title;
  final String heading;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new),
          // The page was reached with `go`, so there is nothing to pop.
          onPressed: () => context.go(HomePage.path),
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
