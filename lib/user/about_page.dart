import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? fullname;
  String? email;
  bool loading = true;
  bool isSearching = false;
  String searchQuery = '';
  bool _noInternet = false;
  final TextEditingController _searchController = TextEditingController();

  final String aboutText = '''
Fireguard is an innovative IoT-based solution designed to provide peace of mind for individuals living alone by ensuring their home is always monitored for fire risks. The system integrates advanced sensors and smart technologies to detect potential fire hazards, smoke, and abnormal temperature fluctuations, sending real-time alerts directly to the user's phone or other connected devices.

With Fireguard, users can stay informed about the safety of their home, even when they are away. The system offers constant monitoring, instantly notifying users in the event of a fire or any emergency situation, helping to prevent disasters before they escalate.

Fireguard is a reliable companion for those living alone, offering a simple, smart, and effective way to safeguard their homes and well-being.
''';

  final List<Map<String, String>> fireTeams = [
    {'name': 'National Emergency Hotline', 'contact': '911'},
    {'name': 'Bagumbayan', 'contact': '+639293364778'},
    {'name': 'Bambang', 'contact': '0289953459'},
    {'name': 'Calzada-Tipas', 'contact': '+639190968209'},
    {'name': 'Comembo', 'contact': '0277381883'},
    {'name': 'Ibayo-Tipas', 'contact': '+639189620231'},
    {'name': 'Hagonoy', 'contact': '0270009532'},
    {'name': 'Ligid-Tipas', 'contact': '0286424745'},
    {'name': 'Lower Bicutan', 'contact': '+639483663755'},
    {'name': 'Napindan', 'contact': '0282535606'},
    {'name': 'New Lower Bicutan', 'contact': '0288082722'},
    {'name': 'Palingon-Tipas', 'contact': '0286407773'},
    {'name': 'Pembo', 'contact': '0288565672'},
    {'name': 'Rizal', 'contact': '0277291995'},
    {'name': 'San Miguel', 'contact': '+639672112106'},
    {'name': 'Sta. Ana', 'contact': '0286422228'},
    {'name': 'Tuktukan', 'contact': '0283541107'},
    {'name': 'Ususan', 'contact': '0286409066'},
    {'name': 'Wawa', 'contact': '+639649478238'},
    {'name': 'Cembo', 'contact': '0285329098'},
    {'name': 'Central Bicutan', 'contact': '+639626836893'},
    {'name': 'Central Signal', 'contact': '02888370495'},
    {'name': 'East Rembo', 'contact': '0277281588'},
    {'name': 'Fort Bonifacio', 'contact': '0284772106'},
    {'name': 'Katuparan', 'contact': '0282730592'},
    {'name': 'Maharlika', 'contact': '0288377002'},
    {'name': 'North Daang Hari', 'contact': '0288372658'},
    {'name': 'North Signal', 'contact': '0289839298'},
    {'name': 'Pinagsama', 'contact': '+639150893517'},
    {'name': 'Pitogo', 'contact': '+639663885513'},
    {'name': 'Post Proper Northside', 'contact': '0287881764'},
    {'name': 'Post Proper Southside', 'contact': '0289862484'},
    {'name': 'South Cembo', 'contact': '0270066528'},
    {'name': 'South Daang Hari', 'contact': '+639682555742'},
    {'name': 'South Signal Village', 'contact': '+639981879684'},
    {'name': 'Tanyag', 'contact': '0283717343'},
    {'name': 'Upper Bicutan', 'contact': '+639628451498'},
    {'name': 'Western Bicutan', 'contact': '+639190854155'},
    {'name': 'West Rembo', 'contact': '0288369733'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _noInternet = result == ConnectivityResult.none;
      });
    });
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          setState(() {
            fullname = data?['fullname'] ?? '';
            email = data?['email'] ?? '';
            loading = false;
          });
        } else {
          setState(() {
            fullname = '';
            email = user.email ?? '';
            loading = false;
          });
        }
      } catch (e) {
        print('Error fetching user info: $e');
        setState(() {
          fullname = '';
          email = user.email ?? '';
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load user data: $e',
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() {
        fullname = '';
        email = '';
        loading = false;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      setState(() {
        _noInternet = result == ConnectivityResult.none;
      });
    } catch (e) {
      print('Error checking connectivity: $e');
      setState(() {
        _noInternet = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error checking connectivity: $e',
            style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _callNumber(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Calling is not supported on this device.',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to initiate call: $e',
            style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, String>> _filteredFireTeams() {
    if (searchQuery.isEmpty) {
      return fireTeams;
    }
    return fireTeams.where((team) {
      return team['name']!.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  Image.asset(
                    'assets/logo.png',
                    height: 80,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'Logo not found',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        loading
                            ? const SizedBox(
                                width: 100,
                                height: 24,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                fullname ?? 'User',
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                        Text(
                          loading ? '' : (email ?? ''),
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            color: Colors.white70,
                            fontSize: 16,
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
              selected: false,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/history');
              },
            ),
            _DrawerItem(
              icon: Icons.person,
              label: 'Profile',
              selected: false,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/profile');
              },
            ),
            _DrawerItem(
              icon: Icons.info,
              label: 'About',
              selected: true,
              onTap: () => Navigator.pop(context),
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
                    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                  },
                  child: const Text(
                    'LOGOUT',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
          'About',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Image - fills the screen, not distorted
          Positioned.fill(
            child: Image.asset(
              'assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Semi-transparent overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => const Text(
                      'Logo not found',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Smart Fireguard',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFFE6F4EA).withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        aboutText,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Taguig City Fire Protection Team Contacts',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isSearching ? Icons.close : Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: isSearching ? 'Cancel Search' : 'Search Contacts',
                        onPressed: () {
                          setState(() {
                            isSearching = !isSearching;
                            if (!isSearching) {
                              _searchController.clear();
                              searchQuery = '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (isSearching) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        hintStyle: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFE53935),
                          size: 24,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFFE53935),
                                  size: 24,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFFFEBEE).withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ..._filteredFireTeams().map((team) => Card(
                        color: const Color(0xFFFFEBEE).withOpacity(0.9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE53935), width: 1),
                        ),
                        elevation: 4,
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFF2E7D32),
                            size: 24,
                          ),
                          title: Text(
                            team['name']!,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          subtitle: Text(
                            team['contact']!,
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.call,
                              color: Color(0xFF2E7D32),
                              size: 24,
                            ),
                            onPressed: () => _callNumber(context, team['contact']!),
                          ),
                          onTap: () => _callNumber(context, team['contact']!),
                        ),
                      )),
                ],
              ),
            ),
          ),
          // No Internet Banner
          if (_noInternet)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFFD32F2F),
                padding: const EdgeInsets.all(12),
                child: const SafeArea(
                  child: Center(
                    child: Text(
                      'No internet connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'PressStart2P',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
                  fontFamily: 'PressStart2P',
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