import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../lib/user/register_page.dart';
import 'register_page_test.mocks.dart';

// Mock classes
@GenerateMocks([FirebaseAuth, UserCredential, User, FirebaseDatabase, DatabaseReference, DataSnapshot])
void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;
  late MockFirebaseDatabase mockFirebaseDatabase;
  late MockDatabaseReference mockDeviceIdRef;
  late MockDatabaseReference mockWindIdRef;
  late MockDatabaseReference mockUsersRef;
  late MockDatabaseReference mockDeviceIdsRef;
  late MockDatabaseReference mockWindIdsRef;
  late MockDatabaseReference mockUsersBaseRef;
  late MockDataSnapshot mockDeviceIdSnapshot;
  late MockDataSnapshot mockWindIdSnapshot;

  setUp(() {
    // Initialize mocks
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    mockFirebaseDatabase = MockFirebaseDatabase();
    mockDeviceIdRef = MockDatabaseReference();
    mockWindIdRef = MockDatabaseReference();
    mockUsersRef = MockDatabaseReference();
    mockDeviceIdsRef = MockDatabaseReference();
    mockWindIdsRef = MockDatabaseReference();
    mockUsersBaseRef = MockDatabaseReference();
    mockDeviceIdSnapshot = MockDataSnapshot();
    mockWindIdSnapshot = MockDataSnapshot();

    // Setup mock behaviors for FirebaseAuth
    when(mockFirebaseAuth.createUserWithEmailAndPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) async => mockUserCredential);
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');
    when(mockUser.delete()).thenAnswer((_) async => null);

    // Stub ref() for base paths
    when(mockFirebaseDatabase.ref('device_ids')).thenReturn(mockDeviceIdsRef);
    when(mockFirebaseDatabase.ref('wind_ids')).thenReturn(mockWindIdsRef);
    when(mockFirebaseDatabase.ref('users')).thenReturn(mockUsersBaseRef);

    // Stub child() for specific paths
    when(mockDeviceIdsRef.child('device123')).thenReturn(mockDeviceIdRef);
    when(mockDeviceIdsRef.child('invalid_device')).thenReturn(mockDeviceIdRef);
    when(mockWindIdsRef.child('wind456')).thenReturn(mockWindIdRef);
    when(mockUsersBaseRef.child('test_uid')).thenReturn(mockUsersRef);

    // Stub get() and set() for database references
    when(mockDeviceIdRef.get()).thenAnswer((_) async => mockDeviceIdSnapshot);
    when(mockWindIdRef.get()).thenAnswer((_) async => mockWindIdSnapshot);
    when(mockUsersRef.set(any)).thenAnswer((_) async => null);

    // Default snapshot behaviors (override in specific tests)
    when(mockDeviceIdSnapshot.exists).thenReturn(true);
    when(mockWindIdSnapshot.exists).thenReturn(true);
  });

  group('RegisterPage Tests', () {
    testWidgets('RegisterPage renders all input fields', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Verify all input fields are present
      expect(find.text('Device ID'), findsOneWidget);
      expect(find.text('Wind ID'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Contact Number'), findsOneWidget);
      expect(find.text('Google Maps Embed Link'), findsOneWidget);
      expect(find.text('I agree to the Terms and Conditions'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows error when passwords do not match', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Enter valid email and mismatched passwords
      await tester.enterText(find.byType(TextField).at(3), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(4), 'Abcd1234');
      await tester.enterText(find.byType(TextField).at(5), 'Abcd1235');
      await tester.pump();

      // Tap register button
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify error message in Text widget or SnackBar
      expect(find.text('Passwords do not match.'), findsWidgets);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows terms and conditions dialog when tapped', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure the terms text is visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Tap terms and conditions text
      await tester.tap(find.text('I agree to the Terms and Conditions'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('Terms and Conditions'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows embed link tutorial dialog when help icon tapped', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure the help icon is visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Tap help icon for Google Maps Embed Link
      await tester.tap(find.byIcon(Icons.help_outline), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('How to Get Google Maps Embed Link'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Register button triggers registration process', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Override snapshot behaviors for this test
      when(mockDeviceIdSnapshot.exists).thenReturn(true);
      when(mockWindIdSnapshot.exists).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
          routes: {
            '/login': (context) => const Scaffold(body: Text('Login Page')),
          },
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Fill in all fields
      await tester.enterText(find.byType(TextField).at(0), 'device123');
      await tester.enterText(find.byType(TextField).at(1), 'wind456');
      await tester.enterText(find.byType(TextField).at(2), 'John Doe');
      await tester.enterText(find.byType(TextField).at(3), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(4), 'Abcd1234');
      await tester.enterText(find.byType(TextField).at(5), 'Abcd1234');
      await tester.enterText(find.byType(TextField).at(6), '1234567890');
      await tester.enterText(find.byType(TextField).at(7), 'https://www.google.com/maps/embed?...');

      // Show and accept terms and conditions
      await tester.ensureVisible(find.text('I agree to the Terms and Conditions'));
      await tester.tap(find.text('I agree to the Terms and Conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Accept'));
      await tester.pumpAndSettle();

      // Debug: Verify checkbox state
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      print('Checkbox value: ${checkbox.value}');

      // Ensure register button is visible and tap it
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Debug: Print widget tree and check for error messages
      if (find.text('Login Page').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify navigation to login page
      expect(find.text('Login Page'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows error when device ID is invalid', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      // Override snapshot behavior for invalid device ID
      when(mockDeviceIdSnapshot.exists).thenReturn(false);
      when(mockWindIdSnapshot.exists).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Fill in all fields
      await tester.enterText(find.byType(TextField).at(0), 'invalid_device');
      await tester.enterText(find.byType(TextField).at(1), 'wind456');
      await tester.enterText(find.byType(TextField).at(2), 'John Doe');
      await tester.enterText(find.byType(TextField).at(3), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(4), 'Abcd1234');
      await tester.enterText(find.byType(TextField).at(5), 'Abcd1234');
      await tester.enterText(find.byType(TextField).at(6), '1234567890');
      await tester.enterText(find.byType(TextField).at(7), 'https://www.google.com/maps/embed?...');

      // Show and accept terms and conditions
      await tester.ensureVisible(find.text('I agree to the Terms and Conditions'));
      await tester.tap(find.text('I agree to the Terms and Conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Accept'));
      await tester.pumpAndSettle();

      // Debug: Verify checkbox state
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      print('Checkbox value: ${checkbox.value}');

      // Ensure register button is visible and tap it
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Debug: Print widget tree and check for error messages
      if (find.text('Device ID not found or not available.').evaluate().isEmpty) {
        debugDumpApp();
        final allText = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print('All text widgets: $allText');
      }

      // Verify error message in Text widget or SnackBar
      expect(find.text('Device ID not found or not available.'), findsWidgets);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows email validation error when invalid email is entered', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.byType(TextField).at(3), 'invalid_email');
      await tester.pumpAndSettle();

      // Verify error message
      expect(find.text('Please enter a valid email address.'), findsOneWidget);

      // Reset view
      tester.view.reset();
    });

    testWidgets('Shows password validation error when invalid password is entered', (WidgetTester tester) async {
      // Set test window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterPage(
            firebaseAuth: mockFirebaseAuth,
            firebaseDatabase: mockFirebaseDatabase,
          ),
        ),
      );

      // Scroll to ensure fields are visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Enter invalid password
      await tester.enterText(find.byType(TextField).at(4), 'weak');
      await tester.pumpAndSettle();

      // Verify error message
      expect(
        find.text('Password must be at least 8 chars, include upper, lower, and a number.'),
        findsOneWidget,
      );

      // Reset view
      tester.view.reset();
    });
  });
}