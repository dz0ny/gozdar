import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/widgets/log_card.dart';

void main() {
  Future<BoxDecoration> pumpCard(WidgetTester tester, bool highlighted) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogCard(
            logEntry: LogEntry(id: 1, volume: 0.5, diameter: 40, length: 4),
            highlighted: highlighted,
            onTap: () {},
            onDismissed: () {},
          ),
        ),
      ),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Container),
      ).first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('the log added last is marked, others are not', (tester) async {
    final plain = await pumpCard(tester, false);
    expect(plain.color, isNull);
    expect((plain.border! as Border).left.color, Colors.transparent);

    final marked = await pumpCard(tester, true);
    final scheme = Theme.of(tester.element(find.byType(LogCard))).colorScheme;
    expect(marked.color, scheme.primaryContainer);
    expect((marked.border! as Border).left.color, scheme.primary);
  });
}
