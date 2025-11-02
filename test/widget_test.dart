// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym/main.dart';

void main() {
  testWidgets('Debug - see what is in the app', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Print all Text widgets
    print('=== ALL TEXT WIDGETS ===');
    final textWidgets = find.byType(Text).evaluate();
    for (final element in textWidgets) {
      final widget = element.widget as Text;
      print('Text found: "${widget.data}"');
    }

    // Print all Icons
    print('=== ALL ICONS ===');
    final icons = find.byType(Icon).evaluate();
    for (final element in icons) {
      final widget = element.widget as Icon;
      print('Icon found: ${widget.icon}');
    }
  });
}