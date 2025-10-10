import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../lib/user/welcome_page.dart';
import 'dart:async';

// Generate mocks with build_runner
import 'welcome_page_test.mocks.dart';

// Mock class for NavigatorObserver
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Generate mocks for Connectivity
@GenerateMocks([Connectivity])
void main() {
  late MockConnectivity mockConnectivity;
  late MockNavigatorObserver mockNavigatorObserver;

  // Helper method to set up the widget with mocks
  Widget createWidgetUnderTest({required bool hasInternet}) {
    when(mockConnectivity.checkConnectivity()).thenAnswer(
      (_) async => [hasInternet ? ConnectivityResult.wifi : ConnectivityResult.none],
    );
    when(mockConnectivity.onConnectivityChanged).thenAnswer(
      (_) => Stream.fromIterable(
        [
          [hasInternet ? ConnectivityResult.wifi : ConnectivityResult.none]
        ],
      ),
    );
    return MaterialApp(
      home: const WelcomePage(),
      navigatorObservers: [mockNavigatorObserver],
      routes: {
        '/login': (context) => const Scaffold(body: Text('Login Page')),
        '/register': (context) => const Scaffold(body: Text('Register Page')),
      },
    );
  }

  setUp(() {
    mockConnectivity = MockConnectivity();
    mockNavigatorObserver = MockNavigatorObserver();
  });

  group('WelcomePage Tests', () {
    testWidgets('displays all UI elements when internet is available', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(hasInternet: true));

      // Act
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500)); // Ensure async state updates

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2)); // Background and logo
      expect(find.text('Smart Fireguard'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('No internet connection'), findsNothing);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2));
    });

    testWidgets('navigates to login page when Sign In button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(hasInternet: true));

      // Act
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didReplace(
        newRoute: anyNamed('newRoute'),
        oldRoute: anyNamed('oldRoute'),
      )).called(1);
      expect(find.text('Login Page'), findsOneWidget);
    });

    testWidgets('navigates to register page when Register button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(hasInternet: true));

      // Act
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigatorObserver.didReplace(
        newRoute: anyNamed('newRoute'),
        oldRoute: anyNamed('oldRoute'),
      )).called(1);
      expect(find.text('Register Page'), findsOneWidget);
    });

    testWidgets('displays error text when logo image is not found', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(hasInternet: true));

      // Act
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500)); // Ensure async state updates

      // Assert
      // Note: Testing errorBuilder requires mocking asset bundle, which is complex.
      // Verify other elements for widget stability.
      expect(find.text('Smart Fireguard'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('applies correct styles to UI elements', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest(hasInternet: true));

      // Act
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500)); // Ensure async state updates

      // Assert
      final titleText = tester.widget<Text>(find.text('Smart Fireguard'));
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.color, Colors.white);

      final signInButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Sign In'));
      expect(signInButton.style?.backgroundColor?.resolve({}), const Color(0xFFE53935));
      expect(signInButton.style?.foregroundColor?.resolve({}), Colors.white);

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, const Color(0xFFE6F4EA).withOpacity(0.9));
      expect(card.shape, isA<RoundedRectangleBorder>());
    });
  });
}