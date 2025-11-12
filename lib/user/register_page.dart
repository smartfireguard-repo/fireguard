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

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  // Controllers
  final _deviceIdController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  final _embedLinkController = TextEditingController();

  // State
  bool _loading = false;
  String? _error;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;
  bool _showSuccess = false;

  // Animation
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: const Interval(0.5, 1.0)),
    );

    // Initialize Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        if (mounted) {
          _showError("Failed to initialize Firebase: $e");
        }
      }
    });
  }

  // Validation
  bool _isEmailValid(String email) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  bool _isPasswordSecure(String password) =>
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,}$').hasMatch(password);

  Future<bool> _deviceIdExists(String deviceId) async {
    final snapshot = await FirebaseDatabase.instance
        .ref('device_ids/$deviceId')
        .get()
        .timeout(const Duration(seconds: 10));
    return snapshot.exists;
  }

  Future<void> _scanQRCode() async {
    final code = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScanner()),
    );
    if (code != null && mounted) {
      setState(() => _deviceIdController.text = code.toString().trim());
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFE6F4EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 18, color: Color(0xFFE53935), fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Welcome to Smart Fireguard! By using our application, you agree to the following terms and conditions:\n\n'
            '1. User Responsibilities: You are responsible for maintaining the confidentiality of your account and password.\n\n'
            '2. Device and Wind ID Usage: You must provide valid Device and Wind IDs that are registered in our system.\n\n'
            '3. Data Privacy: We collect and store your personal information securely.\n\n'
            '4. Service Availability: We strive to provide reliable service.\n\n'
            '5. Termination: We reserve the right to terminate or suspend your account if you violate these terms.\n\n'
            'By accepting these terms, you acknowledge that you have read, understood, and agree to be bound by them.',
            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Colors.black87),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontFamily: 'PressStart2P', color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final deviceId = _deviceIdController.text.trim();

      // Validate
      if (!_isEmailValid(_emailController.text.trim())) throw "Invalid email address.";
      if (!_isPasswordSecure(_passwordController.text)) throw "Password too weak.";
      if (_passwordController.text != _confirmPasswordController.text) throw "Passwords don't match.";
      if (_embedLinkController.text.trim().isEmpty) throw "Embed link required.";
      if (!_agreedToTerms) throw "You must agree to Terms & Conditions.";

      // Create user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ).timeout(const Duration(seconds: 10));

      final uid = cred.user?.uid;
      if (uid == null) throw "User creation failed.";

      // Check device ID
      if (!await _deviceIdExists(deviceId)) {
        await FirebaseAuth.instance.currentUser?.delete();
        throw "Device ID not found.";
      }

      // Save user data
      await FirebaseDatabase.instance.ref('users/$uid').set({
        'deviceId': deviceId,
        'fullname': _fullnameController.text.trim(),
        'email': _emailController.text.trim(),
        'contact': _contactController.text.trim(),
        'address_embed_link': _embedLinkController.text.trim(),
        'registeredAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      // SUCCESS
      if (mounted) {
        setState(() => _showSuccess = true);
        _successController.forward().then((_) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          });
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted && !_showSuccess) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    for (var c in [
      _deviceIdController,
      _fullnameController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
      _contactController,
      _embedLinkController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmailInvalid = _emailController.text.isNotEmpty && !_isEmailValid(_emailController.text);
    final isPasswordInvalid = _passwordController.text.isNotEmpty && !_isPasswordSecure(_passwordController.text);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: _showSuccess
            ? _buildSuccessAnimation()
            : _loading
                ? _buildLoading()
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/logo.png',
                              height: 120,
                              errorBuilder: (_, __, ___) => const Text(
                                'Logo missing',
                                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Smart Fireguard',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Card(
                            color: Colors.white.withOpacity(0.92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                            ),
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Register',
                                    style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(_deviceIdController, 'Device ID', Icons.devices, scan: true),
                                  const SizedBox(height: 12),
                                  _buildTextField(_fullnameController, 'Full Name', Icons.person),
                                  const SizedBox(height: 12),
                                  _buildTextField(_emailController, 'Email', Icons.email, onChanged: (_) => setState(() {})),
                                  if (isEmailInvalid) _buildErrorText("Invalid email."),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    _passwordController,
                                    'Password',
                                    Icons.lock,
                                    obscure: !_showPassword,
                                    onChanged: (_) => setState(() {}),
                                    suffix: IconButton(
                                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off, color: const Color(0xFFE53935)),
                                      onPressed: () => setState(() => _showPassword = !_showPassword),
                                    ),
                                  ),
                                  if (isPasswordInvalid) _buildErrorText("8+ chars, upper, lower, number."),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    _confirmPasswordController,
                                    'Confirm Password',
                                    Icons.lock,
                                    obscure: !_showConfirmPassword,
                                    suffix: IconButton(
                                      icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off, color: const Color(0xFFE53935)),
                                      onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(_contactController, 'Contact Number', Icons.phone),
                                  const SizedBox(height: 12),
                                  _buildTextField(_embedLinkController, 'Google Maps Embed Link', Icons.location_on),
                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _agreedToTerms,
                                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                                        activeColor: const Color(0xFFE53935),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _showTermsDialog,
                                          child: const Text(
                                            'I agree to the Terms & Conditions',
                                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12, color: Color(0xFFE53935), decoration: TextDecoration.underline),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(_error!, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Color(0xFFE53935)), textAlign: TextAlign.center),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE53935),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: _loading ? null : _register,
                                      child: const Text('Register', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton(
                                      onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/login'),
                                      child: const Text('Already have an account? Login', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFFE53935))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 120, errorBuilder: (_, __, ___) => const Text('Logo missing', style: TextStyle(color: Colors.white))),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text('Registering...', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _successController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.check, size: 70, color: Color(0xFF4CAF50)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _opacityAnimation,
            child: const Text(
              'Registration Successful!',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
            ),
          ),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: _opacityAnimation,
            child: const Text('Redirecting to login...', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onChanged,
    bool scan = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black87, fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        suffixIcon: suffix ?? (scan ? IconButton(icon: const Icon(Icons.camera_alt, color: Color(0xFFE53935)), onPressed: _loading ? null : _scanQRCode) : null),
        filled: true,
        fillColor: const Color(0xFFE6F4EA),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(color: Colors.black87, fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(color: Color(0xFFE53935), fontFamily: 'PressStart2P', fontSize: 12)),
    );
  }
}