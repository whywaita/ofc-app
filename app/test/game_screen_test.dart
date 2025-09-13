import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/main.dart';

void main() {
  testWidgets('practice deal shows 5 cards in tray', (tester) async {
    await tester.pumpWidget(const OfcApp());
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    // モーダルでデフォルト（ランダム）開始を選ぶ
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status:'), findsOneWidget);

    expect(find.textContaining('Tray (5)'), findsOneWidget);
  });
}
