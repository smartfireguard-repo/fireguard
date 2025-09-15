import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_fireguard/main.dart';
import 'package:smart_fireguard/models/notification_type.dart';
import 'package:smart_fireguard/providers/history_provider.dart';
import 'package:smart_fireguard/utils/helpers.dart';
import 'mocks.mocks.dart';

void main() {
  // Initialize the Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSharedPreferences mockPrefs;
  late MockFirebaseDatabase mockDatabase;
  late MockDatabaseReference mockDeviceRef;
  late MockDataSnapshot mockSnapshot;
  late MockDatabaseEvent mockEvent;
  late MockHistoryProvider mockHistoryProvider;
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;
  late MockServiceInstance mockService;
  late MockAndroidServiceInstance mockAndroidService;
  late MockDatabaseReference mockUserLogsRef;
  late StreamController<DatabaseEvent> streamController;

  setUp(() async {
    mockPrefs = MockSharedPreferences();
    mockDatabase = MockFirebaseDatabase();
    mockDeviceRef = MockDatabaseReference();
    mockSnapshot = MockDataSnapshot();
    mockEvent = MockDatabaseEvent();
    mockHistoryProvider = MockHistoryProvider();
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    mockService = MockServiceInstance();
    mockAndroidService = MockAndroidServiceInstance();
    mockUserLogsRef = MockDatabaseReference();
    streamController = StreamController<DatabaseEvent>.broadcast();

    // Mock SharedPreferences behavior
    when(mockPrefs.getString('userId')).thenReturn('testUser');
    when(mockPrefs.getString('deviceId')).thenReturn('testDevice');
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setDouble(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);

    // Mock FirebaseDatabase behavior
    when(mockDatabase.ref(any)).thenReturn(mockDeviceRef);
    when(mockDeviceRef.onValue).thenAnswer((_) => streamController.stream);
    when(mockEvent.snapshot).thenReturn(mockSnapshot);
    when(mockDeviceRef.child(any)).thenReturn(mockUserLogsRef);
    when(mockUserLogsRef.push()).thenReturn(mockUserLogsRef);
    when(mockUserLogsRef.set(any)).thenAnswer((_) async => null);

    // Mock HistoryProvider behavior
    when(mockHistoryProvider.initialize()).thenAnswer((_) async => null);
    when(mockHistoryProvider.notifications).thenReturn([]);
    when(mockHistoryProvider.updateNotifications(any)).thenAnswer((_) async {
      print('Test: updateNotifications called');
      return null;
    });
    when(mockHistoryProvider.updateDeviceData(any, changed: anyNamed('changed'))).thenAnswer((_) async {
      print('Test: updateDeviceData called');
      return null;
    });
  });

  tearDown(() {
    streamController.close();
  });

  group('Fuzzy Logic Tests', () {
    test('fuzzifyTemp returns correct membership values', () {
      final result = fuzzifyTemp(20);
      expect(result['Low'], 1.0);
      expect(result['Medium'], 0.0);
      expect(result['High'], 0.0);

      final result2 = fuzzifyTemp(35);
      expect(result2['Low'], 0.0);
      expect(result2['Medium'], 1.0);
      expect(result2['High'], 0.0);

      final result3 = fuzzifyTemp(55);
      expect(result3['Low'], 0.0);
      expect(result3['Medium'], 0.0);
      expect(result3['High'], 1.0);
    });

    test('fuzzifySmoke returns correct membership values', () {
      final result = fuzzifySmoke(150);
      expect(result['Clean'], 1.0);
      expect(result['Moderate'], 0.0);
      expect(result['Smoky'], 0.0);

      final result2 = fuzzifySmoke(300);
      expect(result2['Clean'], 0.0);
      expect(result2['Moderate'], 1.0);
      expect(result2['Smoky'], 0.0);

      final result3 = fuzzifySmoke(500);
      expect(result3['Clean'], 0.0);
      expect(result3['Moderate'], 0.0);
      expect(result3['Smoky'], 1.0);
    });

    test('determineNotificationType returns correct type', () {
      final fuzzyTemp = {'Low': 0.0, 'Medium': 0.0, 'High': 0.8};
      final fuzzySmoke = {'Clean': 0.0, 'Moderate': 0.0, 'Smoky': 0.8};
      final flame = false;

      expect(
        determineNotificationType(fuzzyTemp, fuzzySmoke, flame),
        NotificationType.emergency.value,
      );

      expect(
        determineNotificationType({'Low': 0.0, 'Medium': 1.0, 'High': 0.0}, fuzzySmoke, flame),
        NotificationType.smokeDetected.value,
      );

      expect(
        determineNotificationType(fuzzyTemp, {'Clean': 1.0, 'Moderate': 0.0, 'Smoky': 0.0}, true),
        NotificationType.flameDetected.value,
      );

      expect(
        determineNotificationType(
          {'Low': 1.0, 'Medium': 0.0, 'High': 0.0},
          {'Clean': 1.0, 'Moderate': 0.0, 'Smoky': 0.0},
          false,
        ),
        isNull,
      );
    });

    test('parseDouble handles different input types', () {
      expect(parseDouble(10), 10.0);
      expect(parseDouble(10.5), 10.5);
      expect(parseDouble('20.5'), 20.5);
      expect(parseDouble('invalid'), isNull);
      expect(parseDouble(null), isNull);
    });
  });

  group('Utility Function Tests', () {
    test('nowDate returns MMDDYYYY format', () {
      expect(nowDate(), matches(r'\d{2}\d{2}\d{4}'));
    });

    test('nowTime returns HH:MM AM/PM format', () {
      expect(nowTime(), matches(r'\d{1,2}:\d{2} (AM|PM)'));
    });
  });

  group('Background Service Tests', () {
    test('onStart processes device data and updates HistoryProvider', () {
      fakeAsync((async) async {
        // Mock device data
        when(mockSnapshot.value).thenReturn({
          'temperature': 55.0,
          'smoke': 500.0,
          'flame': 1,
        });

        // Call onStart
        onStart(mockService);

        // Emit the mocked DatabaseEvent
        streamController.add(mockEvent);

        // Flush async operations
        async.flushMicrotasks();
        async.flushTimers();

        // Verify HistoryProvider and Firebase updates
        verify(mockHistoryProvider.updateNotifications(any)).called(1);
        verify(mockHistoryProvider.updateDeviceData(any, changed: true)).called(1);
        verify(mockUserLogsRef.set(any)).called(1);
      });
    });

    test('onStart skips notification due to rate-limiting', () {
      fakeAsync((async) async {
        // Mock device data for smokeDetected (non-emergency, rate-limited)
        when(mockSnapshot.value).thenReturn({
          'temperature': 30.0,
          'smoke': 500.0,
          'flame': 0,
        });

        // Call onStart
        onStart(mockService);

        // Emit the first event
        streamController.add(mockEvent);

        // Flush async operations
        async.flushMicrotasks();
        async.flushTimers();

        // Verify first update
        verify(mockHistoryProvider.updateNotifications(any)).called(1);
        verify(mockUserLogsRef.set(any)).called(1);

        // Reset call counts to isolate second event
        reset(mockHistoryProvider);
        reset(mockUserLogsRef);

        // Emit the second event immediately (within rate-limiting window)
        streamController.add(mockEvent);

        // Flush async operations again
        async.flushMicrotasks();
        async.flushTimers();

        // Verify no additional updates due to rate-limiting
        verifyNever(mockHistoryProvider.updateNotifications(any));
        verifyNever(mockUserLogsRef.set(any));
      });
    });
  });
}