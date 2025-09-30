import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_fireguard/user/login_page.dart';
import 'package:smart_fireguard/user/history_page.dart';
import '../lib/providers/history_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
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

    // Setup mock behaviors for FirebaseAuth
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser); // Mock currentUser for HistoryPage

    // Mock SharedPreferences with valid non-null values
    SharedPreferences.setMockInitialValues({
      'userId': '',
      'fullname': '',
      'email': '',
      'deviceId': '',
      'notifications': '[]', // Empty list as JSON string
      'sensor_temperature': 0.0,
      'sensor_smoke': 0.0,
      'sensor_flame': false,
    });
  });

  group('LoginPage Tests', () {
    testWidgets('LoginPage renders all input fields and buttons', (WidgetTester tester) async {
      // Set test window size
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

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify all UI elements are present
      expect(find.text('Smart Fireguard'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget); // Initial state: password hidden

      // Reset view
      tester.view.reset();
    });

    testWidgets('Successful login navigates to HistoryPage', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Setup mock for successful login
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'Abcd1234',
      )).thenAnswer((_) async => mockUserCredential);

      // Create HistoryProvider and initialize it
      final historyProvider = HistoryProvider();
      await historyProvider.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => historyProvider,
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
          routes: {
            '/history': (context) => HistoryPage(
              firebaseAuth: FirebaseAuth.instance,
              firebaseDatabase: FirebaseDatabase.instance,
            ),
          },
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Enter valid credentials
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'Abcd1234');
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Debug: Print widget tree if navigation fails
      if (find.byType(HistoryPage).evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify navigation to HistoryPage
      expect(find.byType(HistoryPage), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows error when login credentials are invalid', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Setup mock for failed login
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

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Enter invalid credentials
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongPassword');
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Debug: Print widget tree if error message not found
      if (find.text('The password is invalid.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify error message in Text widget or SnackBar
      expect(find.text('The password is invalid.'), findsWidgets);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Forgot password sends reset email for valid email', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Setup mock for successful password reset
      when(mockFirebaseAuth.sendPasswordResetEmail(email: 'test@example.com')).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => HistoryProvider()..initialize(),
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Enter valid email
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.pumpAndSettle();

      // Tap Forgot Password button
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Debug: Print widget tree if success message not found
      if (find.text('Password reset email sent.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify success message in SnackBar
      expect(find.text('Password reset email sent.'), findsWidgets);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Forgot password shows error for empty email', (WidgetTester tester) async {
      // Set test window size
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

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Leave email field empty
      await tester.pumpAndSettle();

      // Tap Forgot Password button
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Debug: Print widget tree if error message not found
      if (find.text('Please enter your email to reset password.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify error message in Text widget or SnackBar
      expect(find.text('Please enter your email to reset password.'), findsWidgets);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Password visibility toggle works', (WidgetTester tester) async {
      // Set test window size
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

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify initial state: password hidden
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Verify toggled state: password visible
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      // Tap again to toggle back
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      // Verify original state restored
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows loading indicator during sign-in', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Setup mock for delayed login
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'Abcd1234',
      )).thenAnswer((_) => Future.delayed(const Duration(seconds: 2), () => mockUserCredential));

      // Create HistoryProvider and initialize it
      final historyProvider = HistoryProvider();
      await historyProvider.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<HistoryProvider>(
            create: (_) => historyProvider,
            child: LoginPage(firebaseAuth: mockFirebaseAuth),
          ),
          routes: {
            '/history': (context) => HistoryPage(
              firebaseAuth: FirebaseAuth.instance,
              firebaseDatabase: FirebaseDatabase.instance,
            ),
          },
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Enter valid credentials
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'Abcd1234');
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'), warnIfMissed: false);
      await tester.pump(); // Trigger loading state

      // Verify loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);

      // Complete async operation
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify navigation to HistoryPage
      expect(find.byType(HistoryPage), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Don\'t have an account navigates to RegisterPage', (WidgetTester tester) async {
      // Set test window size
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

      // Scroll to ensure button is visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Tap Don't have an account button
      await tester.ensureVisible(find.text("Don't have an account?"));
      await tester.tap(find.text("Don't have an account?"), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Debug: Print widget tree if navigation fails
      if (find.text('Register Page').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify navigation to RegisterPage
      expect(find.text('Register Page'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });
  });
}