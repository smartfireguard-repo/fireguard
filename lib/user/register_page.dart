import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import './widgets/qr_scanner.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _deviceIdController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  final _embedLinkController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Firebase.initializeApp();
        print("Firebase initialized successfully");
      } catch (e) {
        print("Firebase initialization error: $e");
        if (mounted) {
          setState(() {
            _error = "Failed to initialize Firebase: $e";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to initialize Firebase: $e", style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<bool> _deviceIdExists(String deviceId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('device_ids/$deviceId')
          .get()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Device ID check timed out");
      });
      print("Device ID: $deviceId, Exists: ${snapshot.exists}");
      return snapshot.exists;
    } catch (e) {
      print("Error checking device ID: $e");
      rethrow;
    }
  }

  bool _isPasswordSecure(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  Future<void> _scanQRCode() async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanner()),
    );
    if (scannedCode != null && mounted) {
      setState(() {
        _deviceIdController.text = scannedCode.toString().trim();
      });
    }
  }

  Future<void> _register() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    print("Starting registration...");

    try {
      final deviceId = _deviceIdController.text.trim();
      print("Validating inputs...");

      if (!_isEmailValid(_emailController.text.trim())) {
        setState(() {
          _error = "Please enter a valid email address.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter a valid email address.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Email validation failed");
        return;
      }

      if (!_isPasswordSecure(_passwordController.text)) {
        setState(() {
          _error =
              "Password must be at least 8 characters, include upper and lower case letters, and a number.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Password must be at least 8 characters, include upper and lower case letters, and a number.",
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Password validation failed");
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _error = "Passwords do not match.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Passwords do not match.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Password mismatch");
        return;
      }

      if (_embedLinkController.text.trim().isEmpty) {
        setState(() {
          _error = "Please paste your Google Maps embed link.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please paste your Google Maps embed link.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Embed link empty");
        return;
      }

      print("Creating user with email: ${_emailController.text.trim()}");
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Authentication timed out");
      });

      final uid = userCredential.user?.uid;
      if (uid == null) {
        setState(() {
          _error = "Failed to create user account.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to create user account.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("User creation failed: No UID");
        return;
      }

      print("Checking device ID: $deviceId");
      if (!await _deviceIdExists(deviceId)) {
        await FirebaseAuth.instance.currentUser?.delete();
        setState(() {
          _error = "Device ID not found or not available.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Device ID not found or not available.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Device ID check failed: $deviceId");
        return;
      }

      print("Writing user data for UID: $uid");
      await FirebaseDatabase.instance
          .ref('users/$uid')
          .set({
            'deviceId': deviceId,
            'fullname': _fullnameController.text.trim(),
            'email': _emailController.text.trim(),
            'contact': _contactController.text.trim(),
            'address_embed_link': _embedLinkController.text.trim(),
          })
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Database write timed out");
      });

      print("Registration successful, navigating to login");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login').catchError((e) 
        { print("Navigation error: $e");
          setState(() {
            _error = "Navigation error: $e";
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Navigation error: $e", style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
              backgroundColor: const Color(0xFFD32F2F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    } on TimeoutException catch (e) {
      print("Timeout error: ${e.message}");
      if (mounted) {
        setState(() {
          _error = "Operation timed out: ${e.message}";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Operation timed out: ${e.message}", style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuth error: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _error = _mapFirebaseAuthError(e.code);
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapFirebaseAuthError(e.code), style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      print("Firebase Database error: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _error = e.code == 'permission-denied'
              ? "Database access denied. Please check your permissions."
              : "Database error: ${e.message}";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? "Database access denied. Please check your permissions."
                  : "Database error: ${e.message}",
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Unexpected error: $e");
      if (mounted) {
        setState(() {
          _error = "An unexpected error occurred: $e";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An unexpected error occurred: $e", style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      print("Registration process ended");
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Contact support.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    _embedLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordTyped = _passwordController.text.isNotEmpty;
    final isPasswordInvalid = isPasswordTyped && !_isPasswordSecure(_passwordController.text);
    final isEmailTyped = _emailController.text.isNotEmpty;
    final isEmailInvalid = isEmailTyped && !_isEmailValid(_emailController.text);

    return Scaffold(
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
                    'Loading...',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 16,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
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
                          'FireGuard',
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
                                'Register',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _deviceIdController,
                                decoration: InputDecoration(
                                  labelText: 'Device ID',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.devices, color: Color(0xFFE53935)),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.camera_alt, color: Color(0xFFE53935)),
                                    onPressed: _loading ? null : _scanQRCode,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _fullnameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.person, color: Color(0xFFE53935)),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.email, color: Color(0xFFE53935)),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                                onChanged: (_) => setState(() {}),
                              ),
                              if (isEmailInvalid) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  "Please enter a valid email address.",
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontFamily: 'PressStart2P',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.lock, color: Color(0xFFE53935)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword ? Icons.visibility : Icons.visibility_off,
                                      color: const Color(0xFFE53935),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                                onChanged: (_) => setState(() {}),
                              ),
                              if (isPasswordInvalid) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  "Password must be at least 8 chars, include upper, lower, and a number.",
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontFamily: 'PressStart2P',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPasswordController,
                                obscureText: !_showConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.lock, color: Color(0xFFE53935)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                      color: const Color(0xFFE53935),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showConfirmPassword = !_showConfirmPassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _contactController,
                                decoration: InputDecoration(
                                  labelText: 'Contact Number',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFE53935)),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _embedLinkController,
                                decoration: InputDecoration(
                                  labelText: 'Google Maps Embed Link',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFFE53935)),
                                  filled: true,
                                  fillColor: const Color(0xFFE6F4EA),
                                  enabledBorder: OutlineInputBorder(
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
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE53935),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 2,
                                  ),
                                  onPressed: _loading ? null : _register,
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.pushReplacementNamed(context, '/login').catchError((e) {
                                            print("Navigation error: $e");
                                            setState(() {
                                              _error = "Navigation error: $e";
                                              _loading = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Navigation error: $e", style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
                                                backgroundColor: const Color(0xFFD32F2F),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }),
                                  child: const Text(
                                    'Already have an account? Login',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 14,
                                      color: Color(0xFFE53935),
                                    ),
                                  ),
                                ),
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
            ),
    );
  }
}