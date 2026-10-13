import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';

void main() {
  testWidgets('app opens on the home screen', (tester) async {
    await tester.pumpWidget(const StrideQuestApp());
    await tester.pumpAndSettle();

    expect(find.text('StrideQuest'), findsOneWidget);
    expect(find.text('Every run is a quest.'), findsOneWidget);
  });
}
