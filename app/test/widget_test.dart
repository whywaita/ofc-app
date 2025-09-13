import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/main.dart';

void main() {
  testWidgets('home shows only Practice button', (tester) async {
    await tester.pumpWidget(const OfcApp());
    expect(find.text('Practice'), findsOneWidget);
    expect(find.textContaining('Run Sample Match'), findsNothing);
    expect(find.textContaining('OFCP Ready'), findsNothing);
  });
}
