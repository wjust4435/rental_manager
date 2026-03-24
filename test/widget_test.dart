import 'package:flutter_test/flutter_test.dart';
import 'package:rental_manager/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const RentalManagerApp());  // ← changed
    expect(find.text('🏗️ Rental Manager'), findsOneWidget);
  });
}