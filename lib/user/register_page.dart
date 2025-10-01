import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import './widgets/qr_scanner.dart';

class RegisterPage extends StatefulWidget {
  final FirebaseAuth firebaseAuth;
  final FirebaseDatabase firebaseDatabase;

  RegisterPage({
    super.key,
    FirebaseAuth? firebaseAuth,
    FirebaseDatabase? firebaseDatabase,
  })  : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        firebaseDatabase = firebaseDatabase ?? FirebaseDatabase.instance;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _deviceIdController = TextEditingController();
  final _windIdController = TextEditingController();
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
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    // Removed Firebase.initializeApp() as it's handled at the app level
  }

  Future<bool> _deviceIdExists(String deviceId) async {
    try {
      final snapshot = await widget.firebaseDatabase
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

  Future<bool> _windIdExists(String windId) async {
    try {
      final snapshot = await widget.firebaseDatabase
          .ref('wind_ids/$windId')
          .get()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Wind ID check timed out");
      });
      print("Wind ID: $windId, Exists: ${snapshot.exists}");
      return snapshot.exists;
    } catch (e) {
      print("Error checking wind ID: $e");
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

  Future<void> _scanQRCode(String field) async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanner()),
    );
    if (scannedCode != null && mounted) {
      setState(() {
        if (field == 'deviceId') {
          _deviceIdController.text = scannedCode.toString().trim();
        } else if (field == 'windId') {
          _windIdController.text = scannedCode.toString().trim();
        }
      });
    }
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: Color(0xFFE53935),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '''
Welcome to FireGuard! By using our application, you agree to the following terms and conditions:

1. **User Responsibilities**: You are responsible for maintaining the confidentiality of your account and password. You agree to provide accurate and complete information during registration.

2. **Device and Wind ID Usage**: You must provide valid Device and Wind IDs that are registered in our system. Unauthorized use of IDs is prohibited.

3. **Data Privacy**: We collect and store your personal information (e.g., name, email, contact number, and address embed link) securely in our database. We will not share your information without your consent, except as required by law.

4. **Service Availability**: FireGuard strives to provide reliable service, but we are not liable for any interruptions or errors in the application.

5. **Termination**: We reserve the right to terminate or suspend your account if you violate these terms.

By accepting these terms, you acknowledge that you have read, understood, and agree to be bound by them.
                ''',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _termsAccepted = true;
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Accept',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmbedLinkTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'How to Get Google Maps Embed Link',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 18,
            color: Color(0xFFE53935),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '''
Follow these steps to get the embed link from Google Maps:

1. **Open Google Maps**:
   - Go to https://www.google.com/maps on your browser or open the Google Maps app.

2. **Search for Your Location**:
   - Enter the address or location you want to embed in the search bar.
   - Press Enter or click the search icon to find the location.

3. **Access the Share Option**:
   - Once the location is displayed, click on the "Share" button (usually a share icon or text link).

4. **Select Embed a Map**:
   - In the share options, select the "Embed a map" tab or option.
   - You will see an HTML iframe code like `<iframe src="https://www.google.com/maps/embed?..."></iframe>`.

5. **Copy the Embed Link**:
   - Copy the URL inside the `src` attribute of the iframe (e.g., https://www.google.com/maps/embed?...).
   - Paste this URL into the Google Maps Embed Link field in the registration form.

6. **Verify the Link**:
   - Ensure the link starts with "https://www.google.com/maps/embed".
   - Test the link in a browser to confirm it displays the correct location.

**Note**: The embed link must be publicly accessible and correctly formatted for FireGuard to use it.
                ''',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
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
      final windId = _windIdController.text.trim();
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

      if (!_termsAccepted) {
        setState(() {
          _error = "Please accept the Terms and Conditions.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please accept the Terms and Conditions.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Terms not accepted");
        return;
      }

      print("Creating user with email: ${_emailController.text.trim()}");
      final userCredential = await widget.firebaseAuth
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
        await widget.firebaseAuth.currentUser?.delete();
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

      print("Checking wind ID: $windId");
      if (!await _windIdExists(windId)) {
        await widget.firebaseAuth.currentUser?.delete();
        setState(() {
          _error = "Wind ID not found or not available.";
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Wind ID not found or not available.", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            backgroundColor: Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print("Wind ID check failed: $windId");
        return;
      }

      print("Writing user data for UID: $uid");
      await widget.firebaseDatabase
          .ref('users/$uid')
          .set({
            'deviceId': deviceId,
            'windId': windId,
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
        Navigator.pushReplacementNamed(context, '/login').catchError((e) {
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
    _windIdController.dispose();
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
                          'Smart Fireguard',
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
                                key: Key('device_id_field'),
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
                                    onPressed: _loading ? null : () => _scanQRCode('deviceId'),
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
                                key: Key('wind_id_field'),
                                controller: _windIdController,
                                decoration: InputDecoration(
                                  labelText: 'Wind ID',
                                  labelStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: const Icon(Icons.air, color: Color(0xFFE53935)),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.camera_alt, color: Color(0xFFE53935)),
                                    onPressed: _loading ? null : () => _scanQRCode('windId'),
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
                                key: Key('full_name_field'),
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
                                key: Key('email_field'),
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
                                key: Key('password_field'),
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
                                key: Key('confirm_password_field'),
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
                                key: Key('contact_number_field'),
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
                                key: Key('google_maps_field'),
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
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.help_outline, color: Color(0xFFE53935), size: 20),
                                    onPressed: _loading ? null : _showEmbedLinkTutorial,
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
                              Row(
                                children: [
                                  Checkbox(
                                    value: _termsAccepted,
                                    onChanged: _loading
                                        ? null
                                        : (value) {
                                            if (value == true) {
                                              _showTermsAndConditions();
                                            } else {
                                              setState(() {
                                                _termsAccepted = false;
                                              });
                                            }
                                          },
                                    activeColor: const Color(0xFFE53935),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _loading ? null : _showTermsAndConditions,
                                      child: const Text(
                                        'I agree to the Terms and Conditions',
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