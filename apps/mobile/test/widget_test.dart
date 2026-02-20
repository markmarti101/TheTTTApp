import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/main.dart';

void main() {
  testWidgets('App loads without error', (WidgetTester tester) async {
    await tester.pumpWidget(const TrainingTriangleApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
