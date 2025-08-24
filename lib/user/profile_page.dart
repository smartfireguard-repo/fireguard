import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = true;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        _fullnameController.text = data?['fullname'] ?? '';
        _emailController.text = data?['email'] ?? '';
        _contactController.text = data?['contact'] ?? '';
        _addressController.text = data?['address_embed_link'] ?? '';
      }
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance.ref('users/${user.uid}').update({
          'fullname': _fullnameController.text.trim(),
          'email': _emailController.text.trim(),
          'contact': _contactController.text.trim(),
          'address_embed_link': _addressController.text.trim(),
        });
        setState(() {
          _editing = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to update profile: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: $e',
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() {
        _error = 'User not authenticated';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User not authenticated',
            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
          ),
          backgroundColor: Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {
      _loading = false;
    });
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
                        _loading
                            ? const SizedBox(
                                width: 100,
                                height: 24,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _fullnameController.text.isEmpty ? 'User' : _fullnameController.text,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                        Text(
                          _loading ? '' : (_emailController.text.isEmpty ? '' : _emailController.text),
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
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.info,
              label: 'About',
              selected: false,
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/about');
              },
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
          'Profile',
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
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const CircularProgressIndicator(color: Color(0xFFE53935)),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading Profile...',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 16,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile Information',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE53935),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              icon: Icons.person,
                              label: 'Full Name',
                              controller: _fullnameController,
                              enabled: _editing,
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              icon: Icons.email,
                              label: 'Email',
                              controller: _emailController,
                              enabled: false,
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              icon: Icons.phone,
                              label: 'Contact Number',
                              controller: _contactController,
                              enabled: _editing,
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              icon: Icons.location_on,
                              label: 'Google Maps Embed Link',
                              controller: _addressController,
                              enabled: _editing,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 16,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _editing ? const Color(0xFFE53935) : Colors.grey,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            if (_editing) {
                                              _saveProfile();
                                            } else {
                                              setState(() {
                                                _editing = true;
                                              });
                                            }
                                          },
                                    child: Text(
                                      _editing ? 'Save' : 'Edit',
                                      style: const TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_editing) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              setState(() {
                                                _editing = false;
                                                _fetchProfile();
                                              });
                                            },
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontFamily: 'PressStart2P',
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool enabled;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        labelStyle: const TextStyle(
          color: Colors.black87,
          fontFamily: 'PressStart2P',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: const Color(0xFFE6F4EA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(
        color: Colors.black87,
        fontFamily: 'PressStart2P',
        fontSize: 14,
        fontWeight: FontWeight.w600,
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