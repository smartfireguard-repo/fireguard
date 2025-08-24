import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/notification_helper.dart';
import '../providers/history_provider.dart';
import '../models/notification_type.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Filter and delete mode
  String? _filterType;
  DateTime? _filterDate;
  bool _deleteMode = false;
  final Set<int> _selectedForDelete = {};
  bool _sortAscending = false;

  // Firebase references and streams
  DatabaseReference? _deviceRef;
  Query? _logsRef;
  Stream<DatabaseEvent>? _deviceStream;

  // Flag for initial device data load to prevent stale notifications
  bool _isInitialDeviceLoad = true;

  // Real-time status timer
  Timer? _realtimeMonitorTimer;

  // Connectivity state
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isConnecting = false;

  // Rate limiting for SnackBars
  DateTime? _lastSnackBarTime;

  // Rate limiting for saving notifications
  String? _lastNotificationType;
  DateTime? _lastNotificationTime;

  @override
  void initState() {
    super.initState();
    // Start connectivity check and data initialization
    _checkConnectivity().then((_) => _initializeData());
  }

  /// Checks network connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      setState(() {
        _isOnline = result != ConnectivityResult.none;
        _isConnecting = _isOnline;
        _isLoading = true;
      });
    } catch (e) {
      print('Error checking connectivity: $e');
      setState(() {
        _isOnline = false;
        _isConnecting = false;
        _isLoading = true;
      });
      _showSnackBar('Error checking connectivity: $e');
    }
  }

  /// Initializes Firebase references and user data
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _isConnecting = _isOnline;
    });
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      historyProvider.clear();
      _showSnackBar('Please log in to view notifications');
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      setState(() => _isLoading = false);
      return;
    }

    // Initialize provider to load persisted data
    await historyProvider.initialize();

    if (historyProvider.userId != user.uid) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          await historyProvider.saveUserInfo(
            user.uid,
            data?['fullname'] ?? '',
            data?['email'] ?? user.email ?? '',
            data?['deviceId'] ?? '',
          );
        } else {
          await historyProvider.saveUserInfo(
            user.uid,
            '',
            user.email ?? '',
            '',
          );
        }
      } catch (e) {
        _showSnackBar('Failed to load user data: $e');
        setState(() => _isLoading = false);
        return;
      }
    }

    if (_isOnline && historyProvider.deviceId != null && historyProvider.deviceId!.isNotEmpty) {
      _isInitialDeviceLoad = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isOnline && mounted) {
          _listenToDeviceData(historyProvider.deviceId!);
          _startRealtimeMonitor();
          setState(() => _isConnecting = false);
        }
      });
    } else {
      historyProvider.updateRealtimeStatus(false);
      setState(() => _isConnecting = false);
    }
    await _fetchNotificationLogs();
    setState(() => _isLoading = false);
  }

  /// Starts monitoring real-time status
  void _startRealtimeMonitor() {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    _realtimeMonitorTimer?.cancel();
    _realtimeMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final shouldBeActive = _isOnline &&
          historyProvider.lastRealtimeReceived != null &&
          DateTime.now().difference(historyProvider.lastRealtimeReceived!).inSeconds <= 5;
      if (historyProvider.isRealtimeActive != shouldBeActive) {
        historyProvider.updateRealtimeStatus(shouldBeActive);
        setState(() {
          _isConnecting = !shouldBeActive && _isOnline;
        });
      }
    });
  }

  /// Fetches notification logs with filters
  Future<void> _fetchNotificationLogs() async {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || historyProvider.userId != user.uid) {
      _showSnackBar('Please log in to view notifications');
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      return;
    }

    try {
      _logsRef = FirebaseDatabase.instance
          .ref('user_logs/${historyProvider.userId}')
          .orderByChild('timestamp')
          .limitToLast(100);
      _logsRef!.onValue.listen((event) {
        final logs = event.snapshot.value as Map<dynamic, dynamic>?;
        print('Received logs: $logs');
        if (logs != null) {
          final logList = logs.entries.map((e) {
            final notif = Map<String, dynamic>.from(e.value as Map);
            notif['key'] = e.key;
            return notif;
          }).toList()
            ..sort((a, b) => _sortAscending
                ? (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0)
                : (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
          print('Processed logs: $logList');
          historyProvider.updateNotifications(logList);
          setState(() {
            print('Notifications updated: ${historyProvider.notifications}');
            _selectedForDelete.clear();
          });
        } else {
          print('No logs found');
          setState(() {
            historyProvider.updateNotifications([]);
            _selectedForDelete.clear();
          });
        }
      }, onError: (error) {
        print('Logs error: $error');
        _showSnackBar('Failed to fetch notifications: $error', action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _fetchNotificationLogs(),
        ));
      });
    } catch (e) {
      print('Error accessing notifications: $e');
      _showSnackBar('Error accessing notifications: $e');
    }
  }

  /// Listens to real-time device data
  void _listenToDeviceData(String deviceId) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    _deviceRef = FirebaseDatabase.instance.ref('device_ids/$deviceId');
    _deviceStream = _deviceRef!.onValue;
    _deviceStream!.listen((event) {
      final data = event.snapshot.value as Map?;
      print('Received device data: $data');
      if (data != null) {
        bool changed = !_isInitialDeviceLoad;
        _isInitialDeviceLoad = false;
        historyProvider.updateDeviceData(Map<String, dynamic>.from(data), changed: changed);
        if (changed) {
          _processNotification(Map<String, dynamic>.from(data));
        }
      } else {
        historyProvider.clearDeviceData();
        historyProvider.updateRealtimeStatus(false);
        setState(() => _isConnecting = _isOnline);
      }
    }, onError: (error) {
      print('Device data error: $error');
      _showSnackBar('Failed to fetch device data: $error');
      historyProvider.clearDeviceData();
      historyProvider.updateRealtimeStatus(false);
      setState(() => _isConnecting = _isOnline);
    });
  }

  /// Processes and saves notifications using fuzzy logic with rate-limiting
  void _processNotification(Map<String, dynamic> data) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final double? temp = _parseDouble(data['temperature']);
    final double? smoke = _parseDouble(data['smoke']);
    final bool flame = (data['flame'] == 1 || data['flame']?.toString() == '1' || data['flame'] == true);
    final now = DateTime.now();
    print('Parsed data: temp=$temp, smoke=$smoke, flame=$flame');
    final fuzzyTemp = _fuzzifyTemp(temp ?? 0);
    final fuzzySmoke = _fuzzifySmoke(smoke ?? 0);
    print('Fuzzy values: temp=$fuzzyTemp, smoke=$fuzzySmoke');

    String? notifType = _determineNotificationType(fuzzyTemp, fuzzySmoke, flame);
    print('Notification type: $notifType');

    if (notifType == null) return;

    // Rate-limiting: Skip if same type and within 10 seconds
    if (_lastNotificationType == notifType &&
    _lastNotificationTime != null &&
    now.difference(_lastNotificationTime!).inSeconds < 10 &&
    notifType != NotificationType.emergency.value) {
    print('Skipping $notifType notification due to 10-second rate limit');
    return;
  }

    final notif = {
      'type': notifType,
      'date': _nowDate(),
      'time': _nowTime(),
      'smoke': smoke != null ? '${smoke.toStringAsFixed(1)}' : '-',
      'temperature': temp != null ? '${temp.toStringAsFixed(1)}°C' : '-',
      'flame': flame ? 'YES' : 'NO',
      'emergency': notifType == NotificationType.emergency.value ? 'true' : 'false',
      'timestamp': now.millisecondsSinceEpoch,
    };
    print('Creating notification: $notif');

    // Update rate-limiting state
    _lastNotificationType = notifType;
    _lastNotificationTime = now;

    if (historyProvider.userId != null) {
    final ref = FirebaseDatabase.instance.ref('user_logs/${historyProvider.userId}').push();
    print('Saving notification to Firebase: $notif');
    ref.set(notif).then((_) {
      print('Notification saved successfully: $notif');
    }).catchError((error) {
      print('Failed to save notification: $error');
      _showSnackBar('Failed to save notification: $error');
    });
  }

    // Show notification using NotificationHelper
    NotificationHelper.showCustomNotification(notifType);
  }

  /// Determines notification type using fuzzy logic
  String? _determineNotificationType(
  Map<String, double> fuzzyTemp,
  Map<String, double> fuzzySmoke,
  bool flame,
) {
  if (flame) {
    return NotificationType.flameDetected.value;
  }
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7 && (fuzzyTemp['High'] ?? 0) >= 0.7) {
    return NotificationType.emergency.value;
  }
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7) {
    return NotificationType.smokeDetected.value;
  }
  return null;
}

  /// Fuzzy logic for temperature
  Map<String, double> _fuzzifyTemp(double temp) {
    double low = 0, med = 0, high = 0;
    if (temp <= 25) low = 1;
    else if (temp > 25 && temp < 30) low = (30 - temp) / 5;
    if (temp >= 25 && temp <= 45) med = (temp <= 35) ? (temp - 25) / 10 : (45 - temp) / 10;
    if (temp >= 35) high = (temp >= 55) ? 1 : (temp - 35) / 20;
    return {
      'Low': low.clamp(0, 1),
      'Medium': med.clamp(0, 1),
      'High': high.clamp(0, 1),
    };
  }

  /// Fuzzy logic for smoke
  Map<String, double> _fuzzifySmoke(double smoke) {
    double clean = 0, mod = 0, smoky = 0;

    // Clean: Full membership (1) at smoke <= 200, linear decrease to 0 from 200 to 300
    if (smoke <= 200) clean = 1;
    else if (smoke > 200 && smoke < 300) clean = (300 - smoke) / 100;

    // Moderate: 0 at smoke <= 200, linear increase to 1 from 200 to 300,
    // 1 from 300 to 400, linear decrease to 0 from 400 to 500
    if (smoke >= 200 && smoke <= 300) mod = (smoke - 200) / 100;
    else if (smoke > 300 && smoke <= 400) mod = 1;
    else if (smoke > 400 && smoke <= 500) mod = (500 - smoke) / 100;

    // Smoky: 0 at smoke <= 400, linear increase to 1 from 400 to 500, 1 at smoke >= 500
    if (smoke > 400 && smoke <= 500) smoky = (smoke - 400) / 100;
    else if (smoke > 500) smoky = 1;

    return {
      'Clean': clean.clamp(0, 1),
      'Moderate': mod.clamp(0, 1),
      'Smoky': smoky.clamp(0, 1),
    };
  }

  /// Parses dynamic value to double
  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString());
  }

  /// Formats current date as MMDDYYYY
  String _nowDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.year}';
  }

  /// Formats current time as HH:MM AM/PM
  String _nowTime() {
    final now = DateTime.now();
    int hour = now.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12 == 0 ? 12 : hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  /// Shows a rate-limited SnackBar
  void _showSnackBar(String message, {SnackBarAction? action}) {
    final now = DateTime.now();
    if (_lastSnackBarTime == null || now.difference(_lastSnackBarTime!).inSeconds > 5) {
      _lastSnackBarTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
    }
  }

  /// Selects all filtered notifications
  void _selectAllNotifications() {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final filtered = historyProvider.notifications.where((item) {
      bool matchesType = _filterType == null || item['type'] == _filterType;
      bool matchesDate = true;
      if (_filterDate != null) {
        final itemDateStr = item['date'] as String;
        final itemDate = DateTime.parse(
            '${itemDateStr.substring(4, 8)}-${itemDateStr.substring(0, 2)}-${itemDateStr.substring(2, 4)}');
        matchesDate = itemDate.year == _filterDate!.year &&
            itemDate.month == _filterDate!.month &&
            itemDate.day == _filterDate!.day;
      }
      return matchesType && matchesDate;
    }).toList();

    setState(() {
      if (_selectedForDelete.length == filtered.length) {
        _selectedForDelete.clear();
      } else {
        _selectedForDelete.clear();
        for (int i = 0; i < filtered.length; i++) {
          _selectedForDelete.add(i);
        }
      }
    });
  }

  /// Deletes selected notification logs
  Future<void> _deleteSelectedLogs() async {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    if (historyProvider.userId == null) {
      _showSnackBar('User not authenticated, cannot delete notifications');
      setState(() {
        _deleteMode = false;
        _selectedForDelete.clear();
      });
      return;
    }

    if (_selectedForDelete.isEmpty) {
      setState(() {
        _deleteMode = false;
        _selectedForDelete.clear();
      });
      return;
    }

    final filtered = historyProvider.notifications.where((item) {
      bool matchesType = _filterType == null || item['type'] == _filterType;
      bool matchesDate = true;
      if (_filterDate != null) {
        final itemDateStr = item['date'] as String;
        final itemDate = DateTime.parse(
            '${itemDateStr.substring(4, 8)}-${itemDateStr.substring(0, 2)}-${itemDateStr.substring(2, 4)}');
        matchesDate = itemDate.year == _filterDate!.year &&
            itemDate.month == _filterDate!.month &&
            itemDate.day == _filterDate!.day;
      }
      return matchesType && matchesDate;
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE53935),
          ),
        ),
        content: const Text('Are you sure you want to delete the selected notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final toRemove = _selectedForDelete.map((i) => filtered[i]).toList();
    final ref = FirebaseDatabase.instance.ref('user_logs/${historyProvider.userId}');
    final deletionFutures = toRemove.where((item) => item['key'] != null).map((item) {
      return ref.child(item['key']).remove().catchError((error) {
        _showSnackBar('Failed to delete notification: $error');
      });
    }).toList();

    await Future.wait(deletionFutures);
    historyProvider.updateNotifications(
      historyProvider.notifications.where((item) => !toRemove.contains(item)).toList(),
    );
    setState(() {
      _deleteMode = false;
      _selectedForDelete.clear();
    });
    _showSnackBar('Selected notifications deleted');
  }

  /// Shows an optimized filter dialog
  void _showFilterDialog() async {
    String? selectedType = _filterType;
    DateTime? selectedDate = _filterDate;
    bool sortAscending = _sortAscending;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Filter Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935),
                  fontSize: 20,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String?>(
                      value: selectedType,
                      hint: const Text('Select Type'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All')),
                        DropdownMenuItem<String>(
                            value: NotificationType.smokeDetected.value, child: Text('Smoke Detected')),
                        DropdownMenuItem<String>(
                            value: NotificationType.flameDetected.value, child: Text('Flame Detected')),
                        DropdownMenuItem<String>(
                            value: NotificationType.emergency.value, child: Text('Emergency')),
                      ],
                      onChanged: (value) => setState(() => selectedType = value),
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      dropdownColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(
                        selectedDate == null
                            ? 'Select Date'
                            : 'Date: ${DateFormat('MM/dd/yyyy').format(selectedDate ?? DateTime.now())}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today, color: Color(0xFFE53935)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFE53935),
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black87,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFE53935),
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          setState(() => selectedDate = picked);
                        },
                      ),
                    ),
                    if (selectedDate != null)
                      TextButton(
                        onPressed: () => setState(() => selectedDate = null),
                        child: const Text(
                          'Clear Date',
                          style: TextStyle(color: Color(0xFFE53935)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sort Order:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        DropdownButton<bool>(
                          value: sortAscending,
                          items: const [
                            DropdownMenuItem<bool>(value: false, child: Text('Descending')),
                            DropdownMenuItem<bool>(value: true, child: Text('Ascending')),
                          ],
                          onChanged: (value) => setState(() => sortAscending = value ?? false),
                          style: const TextStyle(color: Colors.black87, fontSize: 16),
                          dropdownColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        selectedType = null;
                        selectedDate = null;
                        sortAscending = false;
                      }),
                      child: const Text(
                        'Reset All',
                        style: TextStyle(color: Color(0xFFE53935)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'type': selectedType,
                    'date': selectedDate,
                    'sortAscending': sortAscending,
                  }),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _filterType = result['type'];
        _filterDate = result['date'];
        _sortAscending = result['sortAscending'];
        _selectedForDelete.clear();
      });
      await _fetchNotificationLogs();
    }
  }

  /// Builds splash screen
  Widget _buildSplashScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 120),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            Text(
              _isOnline ? 'Loading Notifications...' : 'Offline: Waiting for Connection...',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 16,
                color: Color(0xFFE53935),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds live sensor data card
  Widget _buildLiveSensorCard(HistoryProvider historyProvider) {
    // Safely access deviceData with defaults
    final deviceData = historyProvider.deviceData;
    String tempValue = '-';
    String smokeValue = '-';
    String flameValue = 'NO';

    if (_isConnecting) {
      tempValue = 'N/A';
      smokeValue = 'N/A';
      flameValue = 'N/A';
    } else if (historyProvider.isRealtimeActive && deviceData != null) {
      // Handle temperature
      final tempRaw = deviceData['temperature'];
      tempValue = _parseDouble(tempRaw)?.toStringAsFixed(1) ?? '-';
      if (tempValue != '-') tempValue += '°C';

      // Handle smoke
      final smokeRaw = deviceData['smoke'];
      smokeValue = _parseDouble(smokeRaw)?.toStringAsFixed(1) ?? '-';

      // Handle flame
      final flameRaw = deviceData['flame'];
      flameValue = (flameRaw == 1 || flameRaw?.toString() == '1' || flameRaw == true) ? 'YES' : 'NO';
    } else if (deviceData != null) {
      // Use persisted data when not active
      final tempRaw = deviceData['temperature'];
      tempValue = _parseDouble(tempRaw)?.toStringAsFixed(1) ?? '-';
      if (tempValue != '-') tempValue += '°C';

      final smokeRaw = deviceData['smoke'];
      smokeValue = _parseDouble(smokeRaw)?.toStringAsFixed(1) ?? '-';

      final flameRaw = deviceData['flame'];
      flameValue = (flameRaw == 1 || flameRaw?.toString() == '1' || flameRaw == true) ? 'YES' : 'NO';
    }

    return Card(
      color: const Color(0xFFE6F4EA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LIVE SENSOR DATA',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: historyProvider.isRealtimeActive ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            Text(
              'Device ID: ${historyProvider.deviceId ?? '-'}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SensorDataColumn(label: 'SMOKE', value: smokeValue),
                _SensorDataColumn(label: 'TEMP', value: tempValue),
                _SensorDataColumn(label: 'FLAME', value: flameValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds history cards with filtering and deletion
  Widget _buildHistoryCards() {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final filtered = historyProvider.notifications.where((item) {
      bool matchesType = _filterType == null || item['type'] == _filterType;
      bool matchesDate = true;
      if (_filterDate != null) {
        final itemDateStr = item['date'] as String;
        final itemDate = DateTime.parse(
            '${itemDateStr.substring(4, 8)}-${itemDateStr.substring(0, 2)}-${itemDateStr.substring(2, 4)}');
        matchesDate = itemDate.year == _filterDate!.year &&
            itemDate.month == _filterDate!.month &&
            itemDate.day == _filterDate!.day;
      }
      return matchesType && matchesDate;
    }).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'History',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
            if (_deleteMode)
              TextButton(
                onPressed: _selectAllNotifications,
                child: Text(
                  _selectedForDelete.length == filtered.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        filtered.isEmpty
            ? const Center(
                child: Text(
                  'No notifications to be shown',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  final isEmergency = item['emergency'] == 'true';
                  final isSelected = _deleteMode && _selectedForDelete.contains(i);
                  return GestureDetector(
                    onTap: _deleteMode
                        ? () => setState(() {
                              _selectedForDelete.contains(i)
                                  ? _selectedForDelete.remove(i)
                                  : _selectedForDelete.add(i);
                            })
                        : null,
                    child: Card(
                      color: isSelected
                          ? Colors.grey.withOpacity(0.5)
                          : isEmergency
                              ? const Color(0xFFFFCDD2)
                              : const Color(0xFFFFEBEE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE53935), width: 1),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['type']!,
                                  style: TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isEmergency
                                        ? Colors.red[900]
                                        : const Color(0xFFE53935),
                                  ),
                                ),
                                if (_deleteMode)
                                  SizedBox(
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected ? Colors.grey[800] : Colors.grey,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _HistoryInfoColumn(label: 'Date', value: item['date']!),
                                _HistoryInfoColumn(label: 'Time', value: item['time']!),
                                _HistoryInfoColumn(label: 'Smoke', value: item['smoke'] ?? '-'),
                                _HistoryInfoColumn(label: 'Temp', value: item['temperature']!),
                                _HistoryInfoColumn(label: 'Flame', value: item['flame']!),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  @override
  void dispose() {
    _deviceRef?.onValue.drain();
    _logsRef?.onValue.drain();
    _realtimeMonitorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        if (_isLoading || historyProvider.userId == null) {
          return _buildSplashScreen();
        }
        if (historyProvider.deviceId == null || historyProvider.deviceId!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSnackBar('No device ID configured. Please set it in the profile.');
          });
        }
        return Scaffold(
          drawer: Drawer(
            backgroundColor: Colors.white,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFE53935),
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                  child: Row(
                    children: [
                      Image.asset('assets/logo.png', height: 80),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            historyProvider.userId == null
                                ? const SizedBox(
                                    width: 100,
                                    height: 24,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.white24,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    historyProvider.fullname ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                            Text(
                              historyProvider.userId == null
                                  ? ''
                                  : (historyProvider.email ?? ''),
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DrawerItem(
                  icon: Icons.history,
                  label: 'Real-time Notification',
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.person,
                  label: 'Profile',
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, '/profile').then((_) => _checkConnectivity()),
                ),
                _DrawerItem(
                  icon: Icons.info,
                  label: 'About',
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, '/about').then((_) => _checkConnectivity()),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        historyProvider.clear();
                        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                      },
                      child: const Text(
                        'LOGOUT',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          appBar: AppBar(
            backgroundColor: const Color(0xFFE53935),
            title: const Text(
              'Real-time Notification',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_alt, color: Colors.white),
                tooltip: 'Filter',
                onPressed: _deleteMode ? null : _showFilterDialog,
              ),
              IconButton(
                icon: Icon(
                  _deleteMode ? Icons.close : Icons.delete,
                  color: Colors.white,
                ),
                tooltip: _deleteMode ? 'Cancel Delete' : 'Delete Notifications',
                onPressed: () => setState(() {
                  _deleteMode = !_deleteMode;
                  if (!_deleteMode) {
                    _selectedForDelete.clear();
                  }
                }),
              ),
              if (_deleteMode)
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  tooltip: 'Confirm Delete',
                  onPressed: _deleteSelectedLogs,
                ),
            ],
          ),
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildLiveSensorCard(historyProvider),
                const SizedBox(height: 16),
                _buildHistoryCards(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFEBEE) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFE53935) : Colors.black87,
                size: 28,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFE53935) : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryInfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryInfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SensorDataColumn extends StatelessWidget {
  final String label;
  final String value;

  const _SensorDataColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}