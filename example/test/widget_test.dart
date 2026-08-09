// Smoke test for the example app: verifies it launches without requiring a
// state-management framework and renders its initial (no-image-picked) UI.
// It does not exercise NidOcr.scan() itself — that needs native ML Kit,
// which isn't available under `flutter test`; see the package's own test
// suite (../test/) for parser/facade coverage.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('renders initial pick-image state', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Pick Front'), findsOneWidget);
    expect(find.text('Pick Back'), findsOneWidget);

    // Scan is disabled until both images are picked.
    final scanButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(scanButton.onPressed, isNull);
  });
}
