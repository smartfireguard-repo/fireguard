import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/notification_type.dart';
import 'dart:async';

class HistoryProvider with ChangeNotifier {
  String? _userId;
  String? _fullname;
  String? _email;
  String? _deviceId;
  Map<String, dynamic>? _deviceData;
  bool _isRealtimeActive = false;
  DateTime? _lastRealtimeReceived;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<DatabaseEvent>? _deviceDataSubscription;
  StreamSubscription<DatabaseEvent>? _notificationAddedSub;
  StreamSubscription<DatabaseEvent>? _notificationChangedSub;
  StreamSubscription<DatabaseEvent>? _notificationRemovedSub;

  String? get userId => _userId;
  String? get fullname => _fullname;
  String? get email => _email;
  String? get deviceId => _deviceId;
  Map<String, dynamic>? get deviceData => _deviceData;
  bool get isRealtimeActive => _isRealtimeActive;
  DateTime? get lastRealtimeReceived => _lastRealtimeReceived;
  List<Map<String, dynamic>> get notifications => _notifications;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      _fullname = prefs.getString('fullname');
      _email = prefs.getString('email');
      _deviceId = prefs.getString('deviceId');
      print('Initialized provider: userId=$_userId, deviceId=$_deviceId');
      final temp = prefs.getDouble('sensor_temperature');
      final smoke = prefs.getDouble('sensor_smoke');
      final flame = prefs.getBool('sensor_flame');
      if (temp != null || smoke != null || flame != null) {
        final persistedData = <String, dynamic>{};
        if (temp != null) persistedData['temperature'] = temp;
        if (smoke != null) persistedData['smoke'] = smoke;
        if (flame != null) persistedData['flame'] = flame ? 1 : 0;
        _deviceData = persistedData;
        print('Loaded persisted sensor data: $persistedData');
      }
      await loadCachedNotifications();
      notifyListeners();
    } catch (e) {
      print('Error initializing provider: $e');
    }
  }

  Future<void> saveUserInfo(String userId, String fullname, String email, String deviceId) async {
    try {
      _userId = userId;
      _fullname = fullname;
      _email = email;
      _deviceId = deviceId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('fullname', fullname);
      await prefs.setString('email', email);
      await prefs.setString('deviceId', deviceId);
      print('Saved user info: userId=$userId, deviceId=$deviceId');
      notifyListeners();
    } catch (e) {
      print('Error saving user info: $e');
    }
  }

  Future<void> loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('notifications');
      print('Cached notifications JSON: $notificationsJson');
      if (notificationsJson != null) {
        _notifications = List<Map<String, dynamic>>.from(
          (jsonDecode(notificationsJson) as List).map((e) => Map<String, dynamic>.from(e)),
        );
        print('Loaded cached notifications: ${_notifications.length} items');
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached notifications: $e');
    }
  }

  Future<void> updateNotifications(List<Map<String, dynamic>> notifications) async {
    notifications.sort((a, b) {
      final aTimestamp = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
      final bTimestamp = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
      return bTimestamp.compareTo(aTimestamp); // Descending order
    });
    _notifications = notifications;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notifications', jsonEncode(notifications));
      print('Saved notifications: ${_notifications.length} items');
    } catch (e) {
      print('Error saving notifications: $e');
    }
    notifyListeners();
  }

  Future<void> updateDeviceData(Map<String, dynamic> data, {bool changed = false}) async {
    _deviceData = data;
    if (changed) {
      _lastRealtimeReceived = DateTime.now();
      _isRealtimeActive = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (data['temperature'] != null) {
        await prefs.setDouble('sensor_temperature', _parseDouble(data['temperature']) ?? 0.0);
      }
      if (data['smoke'] != null) {
        await prefs.setDouble('sensor_smoke', _parseDouble(data['smoke']) ?? 0.0);
      }
      if (data['flame'] != null) {
        await prefs.setBool('sensor_flame', _parseBool(data['flame']));
      }
      print('Saved sensor data: $data');
    } catch (e) {
      print('Error saving sensor data: $e');
    }
    notifyListeners();
  }

  Future<void> startDeviceDataListener() async {
    if (_deviceId == null || _deviceId!.isEmpty) {
      print('Cannot start device data listener: deviceId is null or empty');
      updateRealtimeStatus(false);
      return;
    }

    try {
      _deviceDataSubscription?.cancel();
      final ref = FirebaseDatabase.instance.ref('device_ids/$_deviceId');
      print('Starting device data listener for deviceId: $_deviceId');
      _deviceDataSubscription = ref.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        print('Received device data: $data');
        if (data != null) {
          final formattedData = Map<String, dynamic>.from(data);
          updateDeviceData(formattedData, changed: true);
        } else {
          print('No device data found for deviceId: $_deviceId');
          updateRealtimeStatus(false);
        }
      }, onError: (error) {
        print('Error listening to device data: $error');
        updateRealtimeStatus(false);
      });
    } catch (e) {
      print('Error starting device data listener: $e');
      updateRealtimeStatus(false);
    }
  }

  Map<String, dynamic>? _parseNotification(DataSnapshot snapshot) {
    final data = snapshot.value as Map?;
    if (data == null) {
      print('Snapshot value is null for key: ${snapshot.key}');
      return null;
    }
    final notif = Map<String, dynamic>.from(data);
    notif['key'] = snapshot.key;
    print('Raw snapshot data: $notif');

    // Parse timestamp
    DateTime? timestamp;
    final rawTimestamp = notif['timestamp']?.toString();
    print('Raw timestamp: $rawTimestamp (type: ${rawTimestamp.runtimeType})');
    if (rawTimestamp != null && rawTimestamp.isNotEmpty) {
      try {
        timestamp = DateTime.parse(rawTimestamp);
        print('Parsed timestamp: $timestamp');
      } catch (e) {
        print('Error parsing timestamp: $rawTimestamp | Exception: $e');
        // Try without milliseconds
        final trimmed = rawTimestamp.split('.').first;
        try {
          timestamp = DateTime.parse(trimmed);
          print('Parsed trimmed timestamp: $timestamp');
        } catch (e2) {
          print('Error parsing trimmed timestamp: $trimmed | Exception: $e2');
        }
      }
    }

    notif['date'] = timestamp != null ? DateFormat('MMddyyyy').format(timestamp) : '-';
    notif['time'] = timestamp != null ? DateFormat('HH:mm:ss').format(timestamp) : '-';

    // Parse reason
    String type = NotificationType.defaultNotification.value;
    String smoke = '-';
    String temperature = '-';
    String flame = 'NO';
    bool emergency = false;

    final reason = notif['reason']?.toString() ?? '';
    print('Raw reason: $reason');
    if (reason.isNotEmpty) {
      final smokeMatch = RegExp(r'Smoke:([\d.]+)').firstMatch(reason);
      final tempMatch = RegExp(r'Temp:([\d.]+)°?C?').firstMatch(reason);
      final flameMatch = RegExp(r'Flame:(\d)').firstMatch(reason);

      smoke = smokeMatch?.group(1) ?? '-';
      temperature = tempMatch?.group(1) ?? '-';
      flame = _parseBool(flameMatch?.group(1)) ? 'YES' : 'NO';

      if (reason.contains('Smoke') && double.tryParse(smoke) != null && double.parse(smoke) > 0) {
        type = NotificationType.smokeDetected.value;
      } else if (reason.contains('Flame') && flame == 'YES') {
        type = NotificationType.flameDetected.value;
      }
      if (reason.contains('Alarm triggered')) {
        emergency = true;
      }
    }

    notif['type'] = type;
    notif['smoke'] = smoke;
    notif['temperature'] = temperature;
    notif['flame'] = flame;
    notif['emergency'] = emergency.toString();
    notif['location'] = notif['location']?.toString() ?? 'Unknown';

    print('Parsed notification: $notif');
    return notif;
  }

  Future<void> startNotificationListener() async {
    if (_deviceId == null || _deviceId!.isEmpty) {
      print('Cannot start notification listener: deviceId is null or empty');
      return;
    }

    try {
      _notificationAddedSub?.cancel();
      _notificationChangedSub?.cancel();
      _notificationRemovedSub?.cancel();
      _notifications = [];
      notifyListeners();

      final ref = FirebaseDatabase.instance.ref('user_logs').orderByChild('timestamp');
      print('Starting notification listener for deviceId: $_deviceId');

      _notificationAddedSub = ref.onChildAdded.listen((event) {
        final notif = _parseNotification(event.snapshot);
        if (notif != null && notif['deviceId']?.toString() == _deviceId) {
          if (!_notifications.any((n) => n['key'] == notif['key'])) {
            final newList = [..._notifications, notif];
            updateNotifications(newList);
            print('Added notification: $notif');
          } else {
            print('Duplicate notification skipped: ${notif['key']}');
          }
        } else {
          print('Notification skipped: deviceId mismatch or null (notif.deviceId=${notif?['deviceId']}, _deviceId=$_deviceId)');
        }
      }, onError: (error) {
        print('Error on child added: $error');
      });

      _notificationChangedSub = ref.onChildChanged.listen((event) {
        final notif = _parseNotification(event.snapshot);
        if (notif != null && notif['deviceId']?.toString() == _deviceId) {
          final index = _notifications.indexWhere((item) => item['key'] == notif['key']);
          if (index != -1) {
            _notifications[index] = notif;
            updateNotifications(_notifications.toList());
            print('Updated notification: $notif');
          }
        }
      }, onError: (error) {
        print('Error on child changed: $error');
      });

      _notificationRemovedSub = ref.onChildRemoved.listen((event) {
        final key = event.snapshot.key;
        _notifications.removeWhere((item) => item['key'] == key);
        updateNotifications(_notifications.toList());
        print('Removed notification: key=$key');
      }, onError: (error) {
        print('Error on child removed: $error');
      });
    } catch (e) {
      print('Error starting notification listener: $e');
    }
  }

  void updateRealtimeStatus(bool isActive) {
    _isRealtimeActive = isActive;
    print('Realtime status: isRealtimeActive=$isActive');
    notifyListeners();
  }

  Future<void> clear() async {
    _deviceDataSubscription?.cancel();
    _notificationAddedSub?.cancel();
    _notificationChangedSub?.cancel();
    _notificationRemovedSub?.cancel();
    _userId = null;
    _fullname = null;
    _email = null;
    _deviceId = null;
    _deviceData = null;
    _isRealtimeActive = false;
    _lastRealtimeReceived = null;
    _notifications = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('fullname');
      await prefs.remove('email');
      await prefs.remove('deviceId');
      await prefs.remove('notifications');
      await prefs.remove('sensor_temperature');
      await prefs.remove('sensor_smoke');
      await prefs.remove('sensor_flame');
      print('Cleared all preferences');
    } catch (e) {
      print('Error clearing preferences: $e');
    }
    notifyListeners();
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString());
  }

  bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is double) return val == 1.0;
    final str = val.toString().toLowerCase();
    return str == '1' || str == 'true' || str == 'yes';
  }
}