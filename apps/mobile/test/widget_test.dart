import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:training_triangle/providers/auth_provider.dart';
import 'package:training_triangle/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(skipInit: true),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
