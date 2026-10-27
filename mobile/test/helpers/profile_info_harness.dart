import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/profile/domain/entities/profile.dart';
import 'package:stridequest/features/profile/presentation/bloc/profile_info_bloc.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_info_page.dart';

import 'profile_fixtures.dart';
import 'pump_screen.dart';

/// The Profile info page on a real [ProfileInfoBloc] over [repository].
Widget profileInfoPage(MockProfileRepository repository) => BlocProvider(
  create: (_) => ProfileInfoBloc(repository)..add(const ProfileInfoStarted()),
  child: const ProfileInfoPage(),
);

/// A repository that answers [profile] and accepts every save.
MockProfileRepository repositoryWith(Profile profile) {
  final repository = MockProfileRepository();
  when(() => repository.getProfile()).thenAnswer((_) async => profile);
  when(() => repository.saveProfile(any())).thenAnswer(
    (invocation) async => invocation.positionalArguments.first as Profile,
  );
  return repository;
}

Future<void> pumpProfileInfo(
  WidgetTester tester,
  MockProfileRepository repository, {
  Size size = smallPhone,
  double textScale = 1,
  bool settle = true,
}) => pumpScreen(
  tester,
  profileInfoPage(repository),
  size: size,
  textScale: textScale,
  settle: settle,
);

/// The input box of the field labelled [label].
Finder fieldFor(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// Whether the text field labelled [label] has the keyboard focus.
bool hasFocus(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(of: fieldFor(label), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

/// The picker field labelled [label].
Finder pickerFor(String label) => find
    .descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(InkWell),
    )
    .first;

/// Scrolls [finder] into view, taps it and settles.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The text shown in the text field labelled [label].
String textOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(fieldFor(label)).controller!.text;

/// The [Profile] the last `saveProfile` got.
Profile savedProfile(MockProfileRepository repository) =>
    verify(() => repository.saveProfile(captureAny())).captured.last as Profile;
