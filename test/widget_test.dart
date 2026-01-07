import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MeteogramApp());

    // App should render a Scaffold
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
