import 'package:crypto_radar/theme/app_theme.dart';
import 'package:crypto_radar/widgets/product_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('important metric has a bright focus border', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            height: 120,
            child: ProductMetricCard(
              label: 'Entry Quality',
              value: '0/100',
              color: Colors.red,
              focusHighlight: true,
            ),
          ),
        ),
      ),
    );

    final Card card = tester.widget<Card>(find.byType(Card));
    final BuildContext context = tester.element(find.byType(Card));
    final RoundedRectangleBorder shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.width, 2.2);
    expect(shape.side.color, Theme.of(context).colorScheme.primary);
    expect(card.elevation, 4);
    expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);
  });
}
