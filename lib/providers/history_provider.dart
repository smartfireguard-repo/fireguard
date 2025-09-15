import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class HistoryProvider with ChangeNotifier {
  String? _userId;
  String? _fullname;
  String? _email;
  String? _deviceId;
  Map<String, dynamic>? _deviceData;
  List<Map<String, dynamic>> _notifications = [];
  bool _isRealtimeActive = false;
  DateTime? _lastUpdateTime;

  String? get userId => _userId;
  String? get fullname => _fullname;
  String? get email => _email;
  String? get deviceId => _deviceId;
  Map<String, dynamic>? get deviceData => _deviceData;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isRealtimeActive => _isRealtimeActive;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _fullname = prefs.getString('fullname');
    _email = prefs.getString('email');
    _deviceId = prefs.getString('deviceId');
    await loadCachedNotifications();
    notifyListeners();
  }

  Future<void> saveUserInfo(String userId, String? fullname, String? email, String? deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = userId;
    _fullname = fullname;
    _email = email;
    _deviceId = deviceId;
    await prefs.setString('userId', userId);
    if (fullname != null) await prefs.setString('fullname', fullname);
    if (email != null) await prefs.setString('email', email);
    if (deviceId != null) await prefs.setString('deviceId', deviceId);
    notifyListeners();
  }

  Future<void> loadCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('notifications') ?? [];
    _notifications = cached.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
    notifyListeners();
  }

  void updateDeviceData(Map<String, dynamic> data, {bool changed = false}) {
    print('Updating device data from Firebase: $data');
    _deviceData = data;
    _isRealtimeActive = true;
    notifyListeners();
  }

  void updateRealtimeStatus(bool status) {
    _isRealtimeActive = status;
    notifyListeners();
  }

  void updateLastUpdateTime(DateTime time) {
    _lastUpdateTime = time;
    notifyListeners();
  }

  Future<void> updateNotifications(List<Map<String, dynamic>> notifications) async {
    _notifications = notifications;
    final prefs = await SharedPreferences.getInstance();
    final encoded = notifications.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('notifications', encoded);
    notifyListeners();
  }

  void clear() {
    _userId = null;
    _fullname = null;
    _email = null;
    _deviceId = null;
    _deviceData = null;
    _notifications = [];
    _isRealtimeActive = false;
    _lastUpdateTime = null;
    notifyListeners();
  }

  double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }
}