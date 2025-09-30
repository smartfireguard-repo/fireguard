import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_fireguard/user/login_page.dart';
import '../lib/providers/history_provider.dart';
import 'login_page_test.mocks.dart';

// Mock classes
@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() async {
    // Initialize mocks
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    // Setup mock behaviors
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'userId': 'test_uid',
      'fullname': 'Test User',
      'email': 'test@example.com',
      'deviceId': 'device_123',
      'notifications': '[]',
      'sensor_temperature': 0.0,
      'sensor_smoke': 0.0,
      'sensor_flame': false,
    });
  });

  group('LoginPage Tests', () {
    testWidgets('Shows error when login credentials are invalid', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'wrongPassword',
      )).thenThrow(FirebaseAuthException(
        code: 'wrong-password',
        message: 'The password is invalid.',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
        ),
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongPassword');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('The password is invalid.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      expect(find.text('The password is invalid.'), findsWidgets);

      tester.view.reset();
    });

    testWidgets('Forgot password sends reset email for valid email', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      when(mockFirebaseAuth.sendPasswordResetEmail(email: 'test@example.com')).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
        ),
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      if (find.text('Password reset email sent.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      expect(find.text('Password reset email sent.'), findsWidgets);

      tester.view.reset();
    });

    testWidgets('Forgot password shows error for empty email', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
        ),
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'), warnIfMissed: false);
      await tester.pumpAndSettle();

      if (find.text('Please enter your email to reset password.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      expect(find.text('Please enter your email to reset password.'), findsWidgets);

      tester.view.reset();
    });

    testWidgets('Password visibility toggle works', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
        ),
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      tester.view.reset();
    });

    testWidgets('Don\'t have an account navigates to RegisterPage', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
          routes: {
            '/register': (context) => const Scaffold(body: Text('Register Page')),
          },
        ),
      );

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text("Don't have an account?"));
      await tester.tap(find.text("Don't have an account?"), warnIfMissed: false);
      await tester.pumpAndSettle();

      if (find.text('Register Page').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      expect(find.text('Register Page'), findsOneWidget);

      tester.view.reset();
    });
  });
}