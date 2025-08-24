import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? fullname;
  String? email;
  bool loading = true;

  final String aboutText = '''
Fireguard is an innovative IoT-based solution designed to provide peace of mind for individuals living alone by ensuring their home is always monitored for fire risks. The system integrates advanced sensors and smart technologies to detect potential fire hazards, smoke, and abnormal temperature fluctuations, sending real-time alerts directly to the user's phone or other connected devices.

With Fireguard, users can stay informed about the safety of their home, even when they are away. The system offers constant monitoring, instantly notifying users in the event of a fire or any emergency situation, helping to prevent disasters before they escalate.

Fireguard is a reliable companion for those living alone, offering a simple, smart, and effective way to safeguard their homes and well-being.
''';

  final List<Map<String, String>> fireTeams = [
    {
      'name': 'Taguig City Fire Station',
      'contact': '0288834762',
    },
    {
      'name': 'Central Signal Fire Sub-Station',
      'contact': '0288834762',
    },
    {
      'name': 'Western Bicutan Fire Sub-Station',
      'contact': '0288834762',
    },
    {
      'name': 'Lower Bicutan Fire Sub-Station',
      'contact': '0288834762',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
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
    } else {
      setState(() {
        fullname = '';
        email = '';
        loading = false;
      });
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
            backgroundColor: Color(0xFFD32F2F),
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
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: Image.asset(
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
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Fireguard',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFE6F4EA),
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
            const Text(
              'Taguig City Fire Protection Team Contacts',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 8),
            ...fireTeams.map((team) => Card(
                  color: const Color(0xFFFFEBEE),
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