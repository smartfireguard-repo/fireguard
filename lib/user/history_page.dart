import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../models/notification_type.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  String? _filterType;
  DateTime? _filterDate;
  bool _deleteMode = false;
  final Set<int> _selectedForDelete = {};
  bool _sortAscending = false;
  final List<Map<String, dynamic>> _deletedNotifications = [];
  Query? _logsRef;
  StreamSubscription<DatabaseEvent>? _deviceDataSubscription;
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isConnecting = false;
  DateTime? _lastSnackBarTime;
  Timer? _timeoutTimer;
  late AnimationController _animationController;
  late Animation<double> _deleteButtonAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _deleteButtonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _checkConnectivity().then((_) => _initializeData());
  }

  @override
  void dispose() {
    _logsRef?.onValue.drain();
    _deviceDataSubscription?.cancel();
    _timeoutTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

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

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();
      
      String fullname = '';
      String email = user.email ?? '';
      String deviceId = '';

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        fullname = data?['fullname']?.toString() ?? '';
        email = data?['email']?.toString() ?? user.email ?? '';
        deviceId = data?['deviceId']?.toString() ?? '';
      }

      await historyProvider.saveUserInfo(user.uid, fullname, email, deviceId);
      print('Loaded deviceId: $deviceId');

      if (deviceId.isEmpty) {
        _showSnackBar('No device ID found. Please set it in Profile.');
        setState(() {
          _isConnecting = false;
          _isLoading = false;
        });
        return;
      }

      if (_isOnline) {
        _setupDeviceDataListener(historyProvider);
      } else {
        historyProvider.updateRealtimeStatus(false);
        setState(() => _isConnecting = false);
      }

      await _fetchNotificationLogs();
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing data: $e');
      _showSnackBar('Failed to load user data: $e');
      setState(() {
        _isConnecting = false;
        _isLoading = false;
      });
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (_isConnecting && mounted) {
        setState(() => _isConnecting = false);
        historyProvider.updateRealtimeStatus(false);
        _showSnackBar('Connection timeout');
      }
    });
  }

  void _setupDeviceDataListener(HistoryProvider historyProvider) {
    final deviceId = historyProvider.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      historyProvider.updateRealtimeStatus(false);
      _showSnackBar('No device ID configured');
      setState(() => _isConnecting = false);
      return;
    }

    final deviceRef = FirebaseDatabase.instance.ref('device_ids/$deviceId');
    _deviceDataSubscription?.cancel();
    print('Attaching listener for device: $deviceId');
    _deviceDataSubscription = deviceRef.onValue.listen(
      (event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        print('Received real-time device data: $data');
        if (data != null) {
          historyProvider.updateDeviceData(Map<String, dynamic>.from(data));
          historyProvider.updateLastUpdateTime(DateTime.now());
          _timeoutTimer?.cancel();
          _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted && historyProvider.lastUpdateTime != null) {
              final elapsed = DateTime.now().difference(historyProvider.lastUpdateTime!).inSeconds;
              if (elapsed >= 5 && historyProvider.isRealtimeActive) {
                historyProvider.updateRealtimeStatus(false);
                print('No data updates for 5 seconds, setting status to inactive');
              }
            }
          });
        } else {
          historyProvider.updateRealtimeStatus(false);
          print('No real-time device data available');
        }
        if (_isConnecting && mounted) {
          setState(() => _isConnecting = false);
        }
      },
      onError: (error) {
        print('Error fetching device data: $error');
        historyProvider.updateRealtimeStatus(false);
        if (mounted) {
          setState(() => _isConnecting = false);
          _showSnackBar('Failed to fetch real-time data: $error');
        }
      },
    );
  }

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
          if (mounted) {
            setState(() => _selectedForDelete.clear());
          }
        } else {
          print('No logs found');
          historyProvider.updateNotifications([]);
          if (mounted) {
            setState(() => _selectedForDelete.clear());
          }
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

  void _showSnackBar(String message, {SnackBarAction? action}) {
    final now = DateTime.now();
    if (_lastSnackBarTime == null || now.difference(_lastSnackBarTime!).inSeconds > 5) {
      _lastSnackBarTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12)),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            action: action,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

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

  Future<void> _deleteSelectedLogs() async {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    if (historyProvider.userId == null) {
      _showSnackBar('User not authenticated');
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
      builder: (context) => _AnimatedConfirmationDialog(),
    );

    if (confirmed != true) return;

    setState(() {
      _selectedForDelete.forEach((i) {
        filtered[i]['isDeleting'] = true;
      });
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final toRemove = _selectedForDelete.map((i) => filtered[i]).toList();
    _deletedNotifications.clear();
    _deletedNotifications.addAll(toRemove);

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
    _showSnackBar(
      'Selected notifications deleted',
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: _undoDelete,
      ),
    );
  }

  Future<void> _undoDelete() async {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    if (_deletedNotifications.isEmpty) return;

    final ref = FirebaseDatabase.instance.ref('user_logs/${historyProvider.userId}');
    final restoreFutures = _deletedNotifications.where((item) => item['key'] != null).map((item) {
      return ref.child(item['key']).set(item).catchError((error) {
        _showSnackBar('Failed to restore notification: $error');
      });
    }).toList();

    await Future.wait(restoreFutures);
    _deletedNotifications.clear();
    await _fetchNotificationLogs();
    _showSnackBar('Notifications restored');
  }

  void _showFilterDialog() async {
    String? selectedType = _filterType;
    DateTime? selectedDate = _filterDate;
    bool sortAscending = _sortAscending;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _AnimatedFilterDialog(
          initialType: selectedType,
          initialDate: selectedDate,
          initialSortAscending: sortAscending,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _filterType = result['type'];
        _filterDate = result['date'];
        _sortAscending = result['sortAscending'];
        _selectedForDelete.clear();
      });
      await _fetchNotificationLogs();
    }
  }

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

  Widget _buildLiveSensorCard(HistoryProvider historyProvider) {
    if (_isConnecting) {
      return Card(
        color: const Color(0xFFE6F4EA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        elevation: 6,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      ),
    );
    }

    String tempValue = 'N/A';
    String smokeValue = 'N/A';
    String flameValue = 'N/A';

    if (historyProvider.isRealtimeActive && historyProvider.deviceData != null) {
      final data = historyProvider.deviceData!;
      final tempRaw = data['temperature'] ?? data['temp'];
      tempValue = historyProvider.parseDouble(tempRaw)?.toStringAsFixed(1) ?? 'N/A';
      if (tempValue != 'N/A') tempValue += '°C';

      final smokeRaw = data['smoke'] ?? data['smokeLevel'];
      smokeValue = historyProvider.parseDouble(smokeRaw)?.toStringAsFixed(1) ?? 'N/A';

      final flameRaw = data['flame'] ?? data['flameDetected'];
      flameValue = (flameRaw == 1 || flameRaw?.toString() == '1' || flameRaw == true ||
              flameRaw?.toString().toLowerCase() == 'yes')
          ? 'YES'
          : 'NO';
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
              'Device ID: ${historyProvider.deviceId ?? 'Not set'}',
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
                  final isDeleting = item['isDeleting'] == true;
                  return AnimatedOpacity(
                    opacity: isDeleting ? 0.0 : isSelected ? 0.6 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedScale(
                      scale: isSelected ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _deleteMode
                            ? () => setState(() {
                                  _selectedForDelete.contains(i)
                                      ? _selectedForDelete.remove(i)
                                      : _selectedForDelete.add(i);
                                })
                            : null,
                        child: Card(
                          color: isSelected
                              ? Colors.grey.withOpacity(0.3)
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
                                      AnimatedScale(
                                        scale: isSelected ? 1.2 : 1.0,
                                        duration: const Duration(milliseconds: 200),
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
                                    _HistoryInfoColumn(label: 'Smoke', value: item['smoke'] ?? 'N/A'),
                                    _HistoryInfoColumn(label: 'Temp', value: item['temperature']!),
                                    _HistoryInfoColumn(label: 'Flame', value: item['flame']!),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        if (_isLoading || historyProvider.userId == null) {
          return _buildSplashScreen();
        }
        return Scaffold(
          drawer: Drawer(
            backgroundColor: Colors.white,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
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
                                      fontFamily: 'PressStart2P',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                            Text(
                              historyProvider.userId == null
                                  ? ''
                                  : (historyProvider.email ?? ''),
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
                  onTap: () => Navigator.pushNamed(context, '/profile').then((_) {
                    _checkConnectivity().then((_) => _initializeData());
                  }),
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
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
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
                icon: const Icon(Icons.filter_alt, color: Colors.white, size: 28),
                tooltip: 'Filter',
                onPressed: _deleteMode ? null : _showFilterDialog,
              ),
              AnimatedBuilder(
                animation: _deleteButtonAnimation,
                builder: (context, child) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _deleteMode = !_deleteMode;
                      if (_deleteMode) {
                        _animationController.forward();
                      } else {
                        _animationController.reverse();
                        _selectedForDelete.clear();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _deleteMode ? Colors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _deleteMode ? Icons.close : Icons.delete,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              if (_deleteMode)
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.white, size: 28),
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

class _AnimatedFilterDialog extends StatefulWidget {
  final String? initialType;
  final DateTime? initialDate;
  final bool initialSortAscending;

  const _AnimatedFilterDialog({
    this.initialType,
    this.initialDate,
    this.initialSortAscending = false,
  });

  @override
  State<_AnimatedFilterDialog> createState() => _AnimatedFilterDialogState();
}

class _AnimatedFilterDialogState extends State<_AnimatedFilterDialog> with SingleTickerProviderStateMixin {
  late String? _selectedType;
  late DateTime? _selectedDate;
  late bool _sortAscending;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedDate = widget.initialDate;
    _sortAscending = widget.initialSortAscending;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE53935), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Center(
                  child: Text(
                    'Filter Notifications',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: DropdownButton<String?>(
                  value: _selectedType,
                  hint: const Text('Select Type', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14)),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14))),
                    DropdownMenuItem<String>(
                      value: NotificationType.smokeDetected.value,
                      child: const Text('Smoke Detected', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14)),
                    ),
                    DropdownMenuItem<String>(
                      value: NotificationType.flameDetected.value,
                      child: const Text('Flame Detected', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14)),
                    ),
                    DropdownMenuItem<String>(
                      value: NotificationType.emergency.value,
                      child: const Text('Emergency', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value),
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  dropdownColor: Colors.white,
                  underline: Container(height: 2, color: const Color(0xFFE53935)),
                ),
              ),
              const Divider(color: Colors.grey, height: 20),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : 'Date: ${DateFormat('MM/dd/yyyy').format(_selectedDate!)}',
                  style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.black87),
                ),
                trailing: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.5, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
                  child: IconButton(
                    icon: const Icon(Icons.calendar_today, color: Color(0xFFE53935)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
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
                      setState(() => _selectedDate = picked);
                    },
                  ),
                ),
              ),
              if (_selectedDate != null)
                TextButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  child: const Text(
                    'Clear Date',
                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Color(0xFFE53935)),
                  ),
                ),
              const Divider(color: Colors.grey, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort Order:',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: DropdownButton<bool>(
                      value: _sortAscending,
                      items: const [
                        DropdownMenuItem<bool>(value: false, child: Text('Descending', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14))),
                        DropdownMenuItem<bool>(value: true, child: Text('Ascending', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14))),
                      ],
                      onChanged: (value) => setState(() => _sortAscending = value ?? false),
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      dropdownColor: Colors.white,
                      underline: Container(height: 2, color: const Color(0xFFE53935)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedType = null;
                    _selectedDate = null;
                    _sortAscending = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'Reset All',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, {
                      'type': _selectedType,
                      'date': _selectedDate,
                      'sortAscending': _sortAscending,
                    }),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedConfirmationDialog extends StatefulWidget {
  @override
  State<_AnimatedConfirmationDialog> createState() => _AnimatedConfirmationDialogState();
}

class _AnimatedConfirmationDialogState extends State<_AnimatedConfirmationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        title: const Text(
          'Delete Notifications',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontWeight: FontWeight.bold,
            color: Color(0xFFE53935),
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete the selected notifications?',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
        child: Row( // ✅ Wrap in Row to allow multiple children
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