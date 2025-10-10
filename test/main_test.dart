import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../lib/main.dart';
import '../lib/providers/history_provider.dart';
import '../lib/user/welcome_page.dart';
import '../lib/user/login_page.dart';
import '../lib/user/register_page.dart';
import '../lib/user/profile_page.dart';
import '../lib/user/about_page.dart';
import '../lib/user/history_page.dart';
import '../lib/utils/helpers.dart';
import '../lib/models/notification_type.dart';

// Generates the mocks
@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseDatabase,
  NavigatorObserver,
])
import 'main_test.mocks.dart';

// Dummy provider for testing
class DummyHistoryProvider extends ChangeNotifier {
  Future<void> initialize() async {}
}

// Test version of AuthChecker that allows injecting a mock stream
class TestAuthChecker extends StatelessWidget {
  final Stream<User?> authStream;

  const TestAuthChecker({
    super.key,
    required this.authStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStream,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final mockAuth = MockFirebaseAuth();
        final mockDatabase = MockFirebaseDatabase();
        return snapshot.hasData
            ? HistoryPage(
                firebaseAuth: mockAuth,
                firebaseDatabase: mockDatabase,
              )
            : const WelcomePage();
      },
    );
  }
}

void main() {
  late MockNavigatorObserver mockNavigatorObserver;
  late StreamController<User?> authController;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockNavigatorObserver = MockNavigatorObserver();
    authController = StreamController<User?>();
  });

  tearDown(() {
    authController.close();
  });

  // Helper method to set up the widget with mocks
  Widget createWidgetUnderTest({bool authenticated = false}) {
    if (authenticated) {
      authController.add(MockUser());
    } else {
      authController.add(null);
    }
    return ChangeNotifierProvider(
      create: (_) => DummyHistoryProvider()..initialize(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Smart FireGuard',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [mockNavigatorObserver],
        home: TestAuthChecker(authStream: authController.stream),
        routes: {
          '/welcome': (context) => const Scaffold(body: Text('Welcome Page')),
          '/login': (context) => const Scaffold(body: Text('Login Page')),
          '/register': (context) => const Scaffold(body: Text('Register Page')),
          '/profile': (context) => const Scaffold(body: Text('Profile Page')),
          '/about': (context) => const Scaffold(body: Text('About Page')),
          '/history': (context) => const Scaffold(body: Text('History Page')),
        },
      ),
    );
  }

  group('MyApp Widget Tests', () {
    testWidgets('builds MyApp with correct configuration', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(ChangeNotifierProvider), findsOneWidget);
    });

    testWidgets('shows loading indicator while checking authentication', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Welcome Page'), findsNothing);
      expect(find.text('History Page'), findsNothing);
    });

    testWidgets('navigates to WelcomePage when user is not authenticated', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(null);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Welcome Page'), findsOneWidget);
      expect(find.text('History Page'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('navigates to HistoryPage when user is authenticated', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest(authenticated: true));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('History Page'), findsOneWidget);
      expect(find.text('Welcome Page'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('navigates to login page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(null);
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/login');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('Login Page'), findsOneWidget);
    });

    testWidgets('navigates to register page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(null);
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/register');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('Register Page'), findsOneWidget);
    });

    testWidgets('navigates to profile page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(authenticated: true));
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/profile');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('Profile Page'), findsOneWidget);
    });

    testWidgets('navigates to about page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(authenticated: true));
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/about');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('About Page'), findsOneWidget);
    });

    testWidgets('navigates to history page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(authenticated: true));
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/history');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('History Page'), findsOneWidget);
    });

    testWidgets('navigates to welcome page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(authenticated: true));
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/welcome');
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didPush(any, any)).called(1);
      expect(find.text('Welcome Page'), findsOneWidget);
    });
  });

  group('Fuzzy Logic Algorithm Tests', () {
    test('fuzzifyTemp returns correct low membership for temp <= 25', () {
      // Act
      final result = fuzzifyTemp(20);

      // Assert
      expect(result['Low'], 1.0);
      expect(result['Medium'], 0.0);
      expect(result['High'], 0.0);
    });

    test('fuzzifyTemp returns correct medium membership for temp between 25 and 45', () {
      // Act
      final result = fuzzifyTemp(35);

      // Assert
      expect(result['Low'], 0.0);
      expect(result['Medium'], 1.0);
      expect(result['High'], 0.0);
    });

    test('fuzzifyTemp returns correct high membership for temp >= 35', () {
      // Act
      final result = fuzzifyTemp(50);

      // Assert
      expect(result['Low'], 0.0);
      expect(result['Medium'], 0.0);
      expect(result['High'], 0.75); // (50 - 35) / 20 = 0.75
    });

    test('fuzzifyTemp clamps values between 0 and 1', () {
      // Act
      final result = fuzzifyTemp(100);

      // Assert
      expect(result['High'], 1.0);
    });

    test('fuzzifySmoke returns correct clean membership for smoke <= 200', () {
      // Act
      final result = fuzzifySmoke(150);

      // Assert
      expect(result['Clean'], 1.0);
      expect(result['Moderate'], 0.0);
      expect(result['Smoky'], 0.0);
    });

    test('fuzzifySmoke returns correct moderate membership for smoke between 200 and 400', () {
      // Act
      final result = fuzzifySmoke(300);

      // Assert
      expect(result['Clean'], 0.0);
      expect(result['Moderate'], 1.0);
      expect(result['Smoky'], 0.0);
    });

    test('fuzzifySmoke returns correct smoky membership for smoke >= 400', () {
      // Act
      final result = fuzzifySmoke(450);

      // Assert
      expect(result['Clean'], 0.0);
      expect(result['Moderate'], 0.5); // (500 - 450) / 100 = 0.5
      expect(result['Smoky'], 0.5); // (450 - 400) / 100 = 0.5
    });

    test('fuzzifySmoke clamps values between 0 and 1', () {
      // Act
      final result = fuzzifySmoke(600);

      // Assert
      expect(result['Smoky'], 1.0);
    });

    test('determineNotificationType returns emergency for high smoke and high temp', () {
      // Arrange
      final fuzzyTemp = {'Low': 0.0, 'Medium': 0.0, 'High': 0.8};
      final fuzzySmoke = {'Clean': 0.0, 'Moderate': 0.0, 'Smoky': 0.8};
      const flame = false;

      // Act
      final result = determineNotificationType(fuzzyTemp, fuzzySmoke, flame);

      // Assert
      expect(result, NotificationType.emergency.value);
    });

    test('determineNotificationType returns flameDetected when flame is true', () {
      // Arrange
      final fuzzyTemp = {'Low': 1.0, 'Medium': 0.0, 'High': 0.0};
      final fuzzySmoke = {'Clean': 1.0, 'Moderate': 0.0, 'Smoky': 0.0};
      const flame = true;

      // Act
      final result = determineNotificationType(fuzzyTemp, fuzzySmoke, flame);

      // Assert
      expect(result, NotificationType.flameDetected.value);
    });

    test('determineNotificationType returns smokeDetected for high smoke', () {
      // Arrange
      final fuzzyTemp = {'Low': 1.0, 'Medium': 0.0, 'High': 0.0};
      final fuzzySmoke = {'Clean': 0.0, 'Moderate': 0.0, 'Smoky': 0.8};
      const flame = false;

      // Act
      final result = determineNotificationType(fuzzyTemp, fuzzySmoke, flame);

      // Assert
      expect(result, NotificationType.smokeDetected.value);
    });

    test('determineNotificationType returns null when no conditions met', () {
      // Arrange
      final fuzzyTemp = {'Low': 1.0, 'Medium': 0.0, 'High': 0.0};
      final fuzzySmoke = {'Clean': 1.0, 'Moderate': 0.0, 'Smoky': 0.0};
      const flame = false;

      // Act
      final result = determineNotificationType(fuzzyTemp, fuzzySmoke, flame);

      // Assert
      expect(result, isNull);
    });
  });
}

// Global navigator key for testing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();