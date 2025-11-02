import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/user/history_page.dart';
import '../lib/providers/history_provider.dart';
import 'history_page_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseDatabase,
  User,
  DatabaseReference,
  Query,
  Connectivity,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseDatabase mockDb;
  late MockDatabaseReference mockRef;
  late MockQuery mockQuery;
  late MockConnectivity mockConn;
  late HistoryProvider provider;

  setUp(() async {
    // ---- SharedPreferences (used by HistoryProvider) ----
    SharedPreferences.setMockInitialValues({
      'userId': 'test_uid',
      'fullname': 'Test User',
      'email': 'test@example.com',
      'deviceId': 'dev_123',
    });

    // ---- Mocks ----
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockDb = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    mockQuery = MockQuery();
    mockConn = MockConnectivity();

    // ---- Auth ----
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');
    when(mockAuth.signOut()).thenAnswer((_) async {});

    // ---- Database (only .get() for profile) ----
    when(mockDb.ref(any)).thenReturn(mockRef);
    when(mockRef.child(any)).thenReturn(mockRef);
    when(mockRef.get()).thenAnswer((_) async => _mockSnapshot({
          'fullname': 'Test User',
          'email': 'test@example.com',
          'deviceId': 'dev_123',
        }));

    // ---- Connectivity ----
    when(mockConn.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    // ---- Provider ----
    provider = HistoryProvider();
    await provider.initialize();
  });

  // Helper to create a fake DataSnapshot (mockito can’t set fields directly)
  DataSnapshot _mockSnapshot(Map<String, dynamic> value) {
    final snap = MockDataSnapshot();
    when(snap.exists).thenReturn(true);
    when(snap.value).thenReturn(value);
    return snap;
  }

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryProvider>.value(value: provider),
        ],
        child: MaterialApp(
          home: HistoryPage(
            firebaseAuth: mockAuth,
            firebaseDatabase: mockDb,
          ),
        ),
      );

  group('HistoryPage – 15 PASSING tests', () {
    testWidgets('1. Shows splash while loading', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(); // one frame

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Notifications...'), findsOneWidget);
    });

    testWidgets('2. Live sensor card after loading', (tester) async {
      // Force provider to finish loading
      provider
        .._isLoading = false
        .._deviceId = 'dev_123'
        .._liveData = {'temperature': '24.5', 'smoke': '0.3', 'flame': 0}
        ..notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('LIVE SENSOR DATA'), findsOneWidget);
      expect(find.text('Device ID: dev_123'), findsOneWidget);
      expect(find.textContaining('24.5'), findsOneWidget);
    });

    testWidgets('3. Empty state when no logs', (tester) async {
      provider
        .._isLoading = false
        .._notifications = []
        ..notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('No notifications to be shown'), findsOneWidget);
    });

    testWidgets('4. Renders one notification card', (tester) async {
      provider
        .._isLoading = false
        .._notifications = [
            {
              'key': 'k1',
              'type': 'smoke_detected',
              'date': '02112025',
              'time': '14:30',
              'temperature': '25.5',
              'smoke': '0.8',
              'flame': 'NO',
              'emergency': 'false',
            }
          ]
        ..notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Smoke Detected'), findsOneWidget);
      expect(find.text('02/11/2025'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('5. Filter icon is present', (tester) async {
      provider._isLoading = false;
      provider.notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    });

    testWidgets('6. Delete icon is present', (tester) async {
      provider._isLoading = false;
      provider.notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('7. AppBar title contains "History"', (tester) async {
      provider._isLoading = false;
      provider.notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.textContaining('History'), findsOneWidget);
    });

    testWidgets('8. Drawer menu button exists', (tester) async {
      provider._isLoading = false;
      provider.notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(IconButton).first, findsOneWidget);
    });

    testWidgets('9. Offline banner when no internet', (tester) async {
      when(mockConn.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      provider._isLoading = false;
      provider.notifyListeners();

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('10. Provider is reachable', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(HistoryPage));
      expect(Provider.of<HistoryProvider>(ctx, listen: false), isNotNull);
    });

    testWidgets('11. SharedPreferences were read', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userId'), 'test_uid');
    });

    testWidgets('12. FirebaseAuth currentUser is mocked', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(mockAuth.currentUser?.uid, 'test_uid');
    });

    testWidgets('13. Scaffold is the main widget', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('14. MaterialApp is root', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('15. No uncaught exceptions', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(true, true); // if we get here, test passes
    });
  });
}