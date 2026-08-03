import 'package:flutter_test/flutter_test.dart';

import 'package:splitnaija/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SplitNaijaApp());
    await tester.pump();

    expect(find.text('SplitNaija'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });
}