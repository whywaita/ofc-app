import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/main.dart';

void main() {
  testWidgets('practice deal shows 5 cards in tray', (tester) async {
    await tester.pumpWidget(const OfcApp());
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    // Modal: choose default (Random) and start
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status:'), findsOneWidget);

    expect(find.textContaining('Tray (5)'), findsOneWidget);
  });
}
