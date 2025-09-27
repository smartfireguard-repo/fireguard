import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../models/notification_type.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? _filterType;
  DateTime? _filterDate;
  bool _deleteMode = false;
  final Set<int> _selectedForDelete = {};
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isConnecting = false;
  DateTime? _lastSnackBarTime;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> _previousNotifications = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity().then((_) => _initializeData());
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      setState(() {
        _isOnline = result != ConnectivityResult.none;
        _isConnecting = _isOnline;
        _isLoading = true;
      });
      if (!_isOnline) {
        Timer(const Duration(seconds: 5), _checkConnectivity);
      }
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

    final user = FirebaseAuth.instance.currentUser;
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    if (user == null) {
      historyProvider.clear();
      _showSnackBar('Please log in to view notifications');
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      setState(() => _isLoading = false);
      return;
    }

    try {
      await historyProvider.initialize();
      print('Initialized provider with userId: ${historyProvider.userId}, deviceId: ${historyProvider.deviceId}');

      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      String fullname = user.displayName ?? '';
      String email = user.email ?? '';
      String deviceId = '';

      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        fullname = data?['fullname']?.toString() ?? fullname;
        deviceId = data?['deviceId']?.toString() ?? '';
      } else {
        print('No user data found for uid: ${user.uid}');
      }

      await historyProvider.saveUserInfo(user.uid, fullname, email, deviceId);
      print('Saved user info: fullname=$fullname, email=$email, deviceId=$deviceId');

      if (_isOnline && deviceId.isNotEmpty) {
        await historyProvider.startDeviceDataListener();
        await historyProvider.startNotificationListener();
        setState(() => _isConnecting = false);
      } else {
        historyProvider.updateRealtimeStatus(false);
        setState(() => _isConnecting = false);
        if (deviceId.isEmpty) {
          _showSnackBar('No device ID configured. Please set it in the profile.');
        } else if (!_isOnline) {
          _showSnackBar('Offline: Cannot fetch live sensor data or notifications.');
        }
      }
    } catch (e) {
      print('Error initializing data: $e');
      _showSnackBar('Failed to initialize data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    final now = DateTime.now();
    if (_lastSnackBarTime == null || now.difference(_lastSnackBarTime!).inSeconds > 5) {
      _lastSnackBarTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'PressStart2P')),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          action: action,
        ),
      );
    }
  }

  void _selectAllNotifications(HistoryProvider provider) {
    final filtered = _getFilteredNotifications(provider);
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

  List<Map<String, dynamic>> _getFilteredNotifications(HistoryProvider provider) {
    final filtered = provider.notifications.where((item) {
      bool matchesType = _filterType == null || item['type'] == _filterType;
      bool matchesDate = true;
      if (_filterDate != null && item['timestamp'] != null) {
        final itemTimestamp = DateTime.tryParse(item['timestamp']?.toString() ?? '');
        matchesDate = itemTimestamp != null &&
            itemTimestamp.year == _filterDate!.year &&
            itemTimestamp.month == _filterDate!.month &&
            itemTimestamp.day == _filterDate!.day;
      }
      return matchesType && matchesDate;
    }).toList();

    // Sort filtered notifications by timestamp in ascending order
    filtered.sort((a, b) {
      final aTimestamp = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime(1970);
      final bTimestamp = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime(1970);
      return bTimestamp.compareTo(aTimestamp); // Descending order (newest first)
    });

    print('Filtered and sorted notifications: ${filtered.map((n) => "${n['timestamp']} - ${n['time']}").toList()}');
    return filtered;
  }

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

    final filtered = _getFilteredNotifications(historyProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
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
    final ref = FirebaseDatabase.instance.ref('user_logs');
    final deletionFutures = toRemove.where((item) => item['key'] != null).map((item) {
      final index = filtered.indexOf(item);
      if (_listKey.currentState != null && index >= 0) {
        _listKey.currentState!.removeItem(
          index,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: _buildNotificationCard(item, index, historyProvider),
          ),
        );
      }
      return ref.child(item['key']).remove().catchError((error) {
        print('Failed to delete notification: $error');
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

  Future<void> _showFilterDialog() async {
    String? selectedType = _filterType;
    DateTime? selectedDate = _filterDate;

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
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 20),
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
                          value: NotificationType.smokeDetected.value,
                          child: const Text('Smoke Detected'),
                        ),
                        DropdownMenuItem<String>(
                          value: NotificationType.flameDetected.value,
                          child: const Text('Flame Detected'),
                        ),
                        DropdownMenuItem<String>(
                          value: NotificationType.emergency.value,
                          child: const Text('Emergency'),
                        ),
                        DropdownMenuItem<String>(
                          value: NotificationType.defaultNotification.value,
                          child: const Text('Other'),
                        ),
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
                            : 'Date: ${DateFormat('MM/dd/yyyy').format(selectedDate!)}',
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
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
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
                        child: const Text('Clear Date', style: TextStyle(color: Color(0xFFE53935))),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        selectedType = null;
                        selectedDate = null;
                      }),
                      child: const Text('Reset All', style: TextStyle(color: Color(0xFFE53935))),
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
        _selectedForDelete.clear();
      });
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) {
      print('Converting int to double: $value');
      return value.toDouble();
    }
    print('Parsing value to double: $value (type: ${value.runtimeType})');
    return double.tryParse(value.toString());
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) {
      print('Converting int to bool: $value');
      return value == 1;
    }
    print('Parsing value to bool: $value (type: ${value.runtimeType})');
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
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
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Color(0xFFE53935)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSensorCard(HistoryProvider historyProvider) {
    final deviceData = historyProvider.deviceData;
    String tempValue = '-';
    String smokeValue = '-';
    String flameValue = 'NO';

    if (_isConnecting) {
      tempValue = 'N/A';
      smokeValue = 'N/A';
      flameValue = 'N/A';
    } else if (historyProvider.isRealtimeActive && deviceData != null) {
      final tempRaw = deviceData['temperature'];
      print('Temperature raw value: $tempRaw (type: ${tempRaw.runtimeType})');
      tempValue = _parseDouble(tempRaw)?.toStringAsFixed(1) ?? '-';
      if (tempValue != '-') tempValue += '°C';

      final smokeRaw = deviceData['smoke'];
      print('Smoke raw value: $smokeRaw (type: ${smokeRaw.runtimeType})');
      smokeValue = _parseDouble(smokeRaw)?.toStringAsFixed(1) ?? '-';

      final flameRaw = deviceData['flame'];
      print('Flame raw value: $flameRaw (type: ${flameRaw.runtimeType})');
      flameValue = _parseBool(flameRaw) ? 'YES' : 'NO';
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
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFF2E7D32)),
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

  Widget _buildNotificationCard(Map<String, dynamic> item, int index, HistoryProvider historyProvider) {
    final isEmergency = item['emergency'] == 'true';
    final isSelected = _deleteMode && _selectedForDelete.contains(index);
    return GestureDetector(
      onTap: _deleteMode
          ? () => setState(() {
                _selectedForDelete.contains(index)
                    ? _selectedForDelete.remove(index)
                    : _selectedForDelete.add(index);
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
                    item['type']?.toString() ?? NotificationType.defaultNotification.value,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isEmergency ? Colors.red[900] : const Color(0xFFE53935),
                    ),
                  ),
                  if (_deleteMode)
                    Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.grey[800] : Colors.grey,
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HistoryInfoColumn(label: 'Date', value: item['date']?.toString() ?? '-'),
                  _HistoryInfoColumn(label: 'Time', value: item['time']?.toString() ?? '-'),
                  _HistoryInfoColumn(label: 'Smoke', value: item['smoke']?.toString() ?? '-'),
                  _HistoryInfoColumn(label: 'Temp', value: item['temperature']?.toString() ?? '-'),
                  _HistoryInfoColumn(label: 'Flame', value: item['flame']?.toString() ?? '-'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCards(HistoryProvider historyProvider) {
    final filtered = _getFilteredNotifications(historyProvider);
    print('Building history cards with filtered notifications: $filtered');
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
                onPressed: () => _selectAllNotifications(historyProvider),
                child: Text(
                  _selectedForDelete.length == filtered.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFFE53935)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        filtered.isEmpty
            ? const Center(
                child: Text(
                  'No notifications to be shown',
                  style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Colors.black54),
                ),
              )
            : AnimatedList(
                key: _listKey,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                initialItemCount: filtered.length,
                itemBuilder: (context, i, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    child: _buildNotificationCard(filtered[i], i, historyProvider),
                  );
                },
              ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        final filtered = _getFilteredNotifications(historyProvider);

        // Detect new notifications and insert them at the bottom (for ascending order)
        if (_listKey.currentState != null && filtered.length > _previousNotifications.length) {
          final newCount = filtered.length - _previousNotifications.length;
          for (int i = 0; i < newCount; i++) {
            _listKey.currentState!.insertItem(filtered.length - 1 - i);
          }
        } else if (_listKey.currentState != null && filtered.length < _previousNotifications.length) {
          final removeCount = _previousNotifications.length - filtered.length;
          for (int i = 0; i < removeCount; i++) {
            _listKey.currentState!.removeItem(
              filtered.length,
              (context, animation) => SizeTransition(
                sizeFactor: animation,
                child: _buildNotificationCard(_previousNotifications[filtered.length + i], filtered.length + i, historyProvider),
              ),
            );
          }
        }

        _previousNotifications = List.from(filtered); // Update previous notifications

        if (_isLoading || historyProvider.userId == null) {
          return _buildSplashScreen();
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
                              historyProvider.email ?? '',
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
                icon: Icon(_deleteMode ? Icons.close : Icons.delete, color: Colors.white),
                tooltip: _deleteMode ? 'Cancel Delete' : 'Delete Notifications',
                onPressed: () => setState(() {
                  _deleteMode = !_deleteMode;
                  if (!_deleteMode) _selectedForDelete.clear();
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
                _buildHistoryCards(historyProvider),
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

  const _DrawerItem({required this.icon, required this.label, required this.selected, required this.onTap});

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
              Icon(icon, color: selected ? const Color(0xFFE53935) : Colors.black87, size: 28),
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
          style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10, color: Colors.black54),
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
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}