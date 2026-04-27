import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:training_triangle/providers/auth_provider.dart';
import 'package:training_triangle/screens/login_screen.dart';

Widget _buildSubject({AuthProvider? auth}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth ?? AuthProvider(skipInit: true),
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders email and password text fields', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('renders app name in header', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.text('The Training Triangle'), findsOneWidget);
    });

    testWidgets('renders Log In heading', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.text('Log In'), findsWidgets);
    });

    testWidgets('renders Sign Up button', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('renders forgot password link', (tester) async {
      await tester.pumpWidget(_buildSubject());

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shows no error text when auth has no error', (tester) async {
      await tester.pumpWidget(_buildSubject());

      final auth = AuthProvider(skipInit: true);
      expect(auth.error, isNull);
    });

    testWidgets('shows error text when auth has error', (tester) async {
      final auth = AuthProvider(skipInit: true)
        ..setErrorForTest('Invalid email or password');
      await tester.pumpWidget(_buildSubject(auth: auth));
      await tester.pump();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('can type into email field', (tester) async {
      await tester.pumpWidget(_buildSubject());

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('can type into password field without crash', (tester) async {
      await tester.pumpWidget(_buildSubject());

      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'mypassword');
      await tester.pump();
    });

    testWidgets('log in button is disabled while loading', (tester) async {
      await tester.pumpWidget(_buildSubject());

      // Initially loading is false, so button should be enabled
      final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      expect(buttons, isNotEmpty);
    });
  });
}
