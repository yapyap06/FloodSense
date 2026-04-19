// FloodSense widget tests

import 'package:flutter_test/flutter_test.dart';
import 'package:floodsense_citizen/app.dart';

void main() {
  testWidgets('FloodSenseApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const FloodSenseApp());
    expect(find.byType(FloodSenseApp), findsOneWidget);
  });
}
