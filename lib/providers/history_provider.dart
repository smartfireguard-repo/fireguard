import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryProvider with ChangeNotifier {
  String? _userId;
  String? _fullname;
  String? _email;
  String? _deviceId;
  Map<String, dynamic>? _deviceData;
  bool _isRealtimeActive = false;
  DateTime? _lastRealtimeReceived;
  List<Map<String, dynamic>> _notifications = [];

  String? get userId => _userId;
  String? get fullname => _fullname;
  String? get email => _email;
  String? get deviceId => _deviceId;
  Map<String, dynamic>? get deviceData => _deviceData;
  bool get isRealtimeActive => _isRealtimeActive;
  DateTime? get lastRealtimeReceived => _lastRealtimeReceived;
  List<Map<String, dynamic>> get notifications => _notifications;

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
      notifyListeners();
    } catch (e) {
      print('Error saving user info: $e');
    }
  }

  Future<void> loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('notifications');
      if (notificationsJson != null) {
        _notifications = List<Map<String, dynamic>>.from(
          (jsonDecode(notificationsJson) as List).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached notifications: $e');
    }
  }

  Future<void> updateNotifications(List<Map<String, dynamic>> notifications) async {
    _notifications = notifications;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notifications', jsonEncode(notifications));
    } catch (e) {
      print('Error saving notifications: $e');
    }
    notifyListeners();
  }

  Future<void> updateDeviceData(Map<String, dynamic> data, {bool changed = false}) async {
    _deviceData = data;
    if (changed) {
      _lastRealtimeReceived = DateTime.now();
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
        await prefs.setBool('sensor_flame', data['flame'] == 1 || data['flame']?.toString() == '1' || data['flame'] == true);
      }
      print('Saved sensor data to SharedPreferences: $data');
    } catch (e) {
      print('Error saving sensor data: $e');
    }
    notifyListeners();
  }

  void updateRealtimeStatus(bool isActive) {
    _isRealtimeActive = isActive;
    notifyListeners();
  }

  void clearDeviceData() {
    _deviceData = null;
    _isRealtimeActive = false;
    _lastRealtimeReceived = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      _fullname = prefs.getString('fullname');
      _email = prefs.getString('email');
      _deviceId = prefs.getString('deviceId');
      // Load persisted sensor data
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

  Future<void> clear() async {
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
}