import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The frame shared by the account forms (Profile info, Email, Password): an
/// app bar with a title and a back button, the form [children], then the
/// [actions] (Save) at the bottom of the content. Large text and the keyboard
/// never overflow it.
///
/// Keyboard handling, with Flutter's own tools:
/// - the `Scaffold` resizes for the keyboard and the body scrolls, so the
///   content ends above the keyboard and Save is always reachable by
///   scrolling; Save sits in the content and moves up with it, never pinned
///   under the keyboard;
/// - a field that gains focus is scrolled into view with its error line (the
///   text field does this itself; [scrollPadding] leaves room below it);
/// - dragging the form (up, or down at its top) or tapping outside a field
///   closes the keyboard.
///
/// Next/Done focus moves and pickers are wired in the forms themselves.
class SettingsFormLayout extends StatelessWidget {
  const SettingsFormLayout({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.onBack,
  });

  /// Bottom room a focused field keeps above the keyboard, enough for its
  /// error line. Pass it as `scrollPadding` of the form's text fields.
  static const scrollPadding = EdgeInsets.only(
    bottom: AppSpacing.xxl + AppSpacing.lg,
  );

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  /// What the back button does. Null shows the default back button when
  /// there is a screen to go back to.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: onBack == null,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          // `onDrag` only fires when the content scrolls. A short form does
          // not scroll on Android (clamping physics), so the drag gesture
          // itself closes the keyboard too. When the content does scroll, the
          // scroll view wins the drag and `onDrag` handles it.
          onVerticalDragStart: (_) => _closeKeyboard(),
          onTap: _closeKeyboard,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.formMaxWidth,
              ),
              // `onDrag` does not close the keyboard when a drag only pulls
              // the content down at its top (Android: nothing moves), so a
              // finger that starts dragging the content closes it here.
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) _closeKeyboard();
                  return false;
                },
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
        ),
      ),
    );
  }
}

void _closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
