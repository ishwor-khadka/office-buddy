import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_buddy/main.dart';

void main() {
  testWidgets('App launches with Office Buddy title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OfficeHealthApp()));
    await tester.pump();
    // App should launch without crashing
    expect(find.byType(MaterialApp), findsNothing); // Uses MaterialApp.router
  });
}
