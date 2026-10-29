import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/delete_account_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/delete_account_page.dart';

import 'auth_fixtures.dart';
import 'pump_screen.dart';
import 'settings_page_harness.dart';

export 'settings_page_harness.dart' show parentText;

const deletePasswordLabel = 'Current Password';

/// The Delete Account page on a real [DeleteAccountBloc] over [repository].
Widget deleteAccountPage(MockAuthRepository repository) => BlocProvider(
  create: (_) => DeleteAccountBloc(repository),
  child: const DeleteAccountPage(),
);

/// A repository that accepts every delete.
MockAuthRepository deleteAccountRepository() {
  final repository = MockAuthRepository();
  when(
    () => repository.deleteAccount(
      currentPassword: any(named: 'currentPassword'),
    ),
  ).thenAnswer((_) async {});
  return repository;
}

/// Makes the next delete fail with [failure].
void failDeleteAccount(MockAuthRepository repository, AuthFailure failure) =>
    when(
      () => repository.deleteAccount(
        currentPassword: any(named: 'currentPassword'),
      ),
    ).thenThrow(failure);

Future<void> pumpDeleteAccount(
  WidgetTester tester,
  MockAuthRepository repository, {
  Size size = smallPhone,
  double textScale = 1,
}) => pumpSettingsPage(
  tester,
  path: DeleteAccountPage.path,
  page: () => deleteAccountPage(repository),
  size: size,
  textScale: textScale,
);

/// The input box of the password field.
Finder get deletePasswordField => find.descendant(
  of: find
      .ancestor(
        of: find.text(deletePasswordLabel),
        matching: find.byType(Column),
      )
      .first,
  matching: find.byType(TextField),
);

/// The Delete account button, the only [FilledButton] on the page.
Finder get deleteButton => find.widgetWithText(FilledButton, 'Delete account');

bool isDeleteEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;
