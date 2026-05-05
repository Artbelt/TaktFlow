import 'package:flutter_test/flutter_test.dart';
import 'package:taktflow/main.dart';

void main() {
  testWidgets('Приложение стартует', (WidgetTester tester) async {
    await tester.pumpWidget(const TaktFlowApp());
    await tester.pump();
    expect(find.text('Шаблоны'), findsWidgets);
  });
}
