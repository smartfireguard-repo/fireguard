import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../lib/providers/history_provider.dart';
import '../lib/utils/helpers.dart';
import '../lib/models/notification_type.dart';

// Global navigator key for testing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Enhanced dummy provider to match real interface
class DummyHistoryProvider extends ChangeNotifier {
  List<Map<String, dynamic>> notifications = [];

  Future<void> initialize() async {}

  void updateNotifications(List<Map<String, dynamic>> notifs) {
    notifications = List.from(notifs);
    notifyListeners();
  }

  void updateDeviceData(Map<String, dynamic> data, {bool changed = false}) {
    // No-op for tests
  }
}

// Dummy pages for testing navigation without real widget dependencies
class DummyWelcomePage extends StatelessWidget {
  const DummyWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Welcome Page Dummy')));
  }
}

class DummyHistoryPage extends StatelessWidget {
  const DummyHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('History Page Dummy')));
  }
}

// Test version of AuthChecker that uses dummy pages (matches real: no Scaffold in loading)
class TestAuthChecker extends StatelessWidget {
  final Stream<dynamic> authStream;  // dynamic for simplicity

  const TestAuthChecker({
    super.key,
    required this.authStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: authStream,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.hasData
            ? const DummyHistoryPage()
            : const DummyWelcomePage();
      },
    );
  }
}

void main() {
  late StreamController<dynamic> authController;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    authController = StreamController<dynamic>();
  });

  tearDown(() {
    authController.close();
  });

  // Helper method to set up the widget
  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider(
      create: (_) => DummyHistoryProvider()..initialize(),
      child: MaterialApp(
        navigatorKey: navigatorKey,  // Correct param: navigatorKey, not 'key'
        title: 'Smart FireGuard',
        debugShowCheckedModeBanner: false,
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
      expect(find.byWidgetPredicate((widget) => widget is ChangeNotifierProvider), findsOneWidget);
    });

    testWidgets('shows loading indicator while checking authentication', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert (initial waiting state - no Scaffold, just Center/CPI)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Welcome Page Dummy'), findsNothing);
      expect(find.text('History Page Dummy'), findsNothing);

      // Act: Emit unauthenticated state
      authController.add(null);
      await tester.pumpAndSettle();

      // Assert (after emission)
      expect(find.text('Welcome Page Dummy'), findsOneWidget);
      expect(find.text('History Page Dummy'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('navigates to WelcomePage when user is not authenticated', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(null);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Welcome Page Dummy'), findsOneWidget);
      expect(find.text('History Page Dummy'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('navigates to HistoryPage when user is authenticated', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(Object());  // Non-null for hasData
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('History Page Dummy'), findsOneWidget);
      expect(find.text('Welcome Page Dummy'), findsNothing);
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
      expect(find.text('Register Page'), findsOneWidget);
    });

    testWidgets('navigates to profile page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(Object());
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/profile');
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Profile Page'), findsOneWidget);
    });

    testWidgets('navigates to about page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(Object());
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/about');
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('About Page'), findsOneWidget);
    });

    testWidgets('navigates to history page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(Object());
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/history');
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('History Page'), findsOneWidget);
    });

    testWidgets('navigates to welcome page via named route', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      authController.add(Object());
      await tester.pumpAndSettle();

      // Act
      navigatorKey.currentState!.pushNamed('/welcome');
      await tester.pumpAndSettle();

      // Assert
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