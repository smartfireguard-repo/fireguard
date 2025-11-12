import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'history_page.dart';

class LoginPage extends StatefulWidget {
  final FirebaseAuth firebaseAuth;
  const LoginPage({super.key, required this.firebaseAuth});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  bool _showSuccess = false;

  late final AnimationController _anim;
  late final Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.5, 1)));
  }

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      await widget.firebaseAuth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() => _showSuccess = true);
        _anim.forward().then((_) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HistoryPage(
                    firebaseAuth: FirebaseAuth.instance,
                    firebaseDatabase: FirebaseDatabase.instance,
                  ),
                ),
                (route) => false,
              );
            }
          });
        });
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } finally {
      if (mounted && !_showSuccess) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return _showError('Please enter your email to reset password.');

    try {
      await widget.firebaseAuth.sendPasswordResetEmail(email: email);
      _showSnack('Password reset email sent.', success: true);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to send reset email.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
    if (!_showSuccess) setState(() => _loading = false);
    _showSnack(msg);
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
        backgroundColor: success ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Image.asset(
                            'assets/logo.png',
                            height: 120,
                            errorBuilder: (_, __, ___) => const Text(
                              'Logo missing',
                              style: TextStyle(color: Colors.white, fontFamily: 'PressStart2P'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            'Smart Fireguard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form Card
                          Card(
                            color: const Color(0xFFE6F4EA).withOpacity(0.95),
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
                                    'Sign In',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE53935),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Email
                                  TextField(
                                    controller: _emailController,
                                    decoration: _inputDecoration('Email', Icons.email),
                                    style: _textFieldStyle(),
                                  ),
                                  const SizedBox(height: 12),

                                  // Password
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    decoration: _inputDecoration(
                                      'Password',
                                      Icons.lock,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _showPassword ? Icons.visibility : Icons.visibility_off,
                                          color: const Color(0xFFE53935),
                                        ),
                                        onPressed: () => setState(() => _showPassword = !_showPassword),
                                      ),
                                    ),
                                    style: _textFieldStyle(),
                                  ),
                                  const SizedBox(height: 16),

                                  // SIGN IN BUTTON – CENTERED
                                  Center(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _signIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE53935),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text(
                                          'Sign In',
                                          style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Links
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/register'),
                                        child: const Text("Register?", style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFFE53935))),
                                      ),
                                      TextButton(
                                        onPressed: _loading ? null : _forgotPassword,
                                        child: const Text('Forgot Password?', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFFE53935))),
                                      ),
                                    ],
                                  ),

                                  // Error
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(_error!, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Color(0xFFE53935)), textAlign: TextAlign.center),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // === REUSABLE STYLES (100% same as original) ===
  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFE6F4EA),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  TextStyle _textFieldStyle() => const TextStyle(color: Colors.black87, fontFamily: 'PressStart2P', fontSize: 14, fontWeight: FontWeight.w600);

  // === LOADING & SUCCESS SCREENS ===
  Widget _buildLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 120),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text('Loading...', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Colors.white)),
          ],
        ),
      );

  Widget _buildSuccessAnimation() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.check, size: 70, color: Color(0xFF4CAF50)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fade,
              child: const Text(
                'Login Successful!',
                style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _fade,
              child: const Text('Welcome back!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 14, color: Colors.white70)),
            ),
          ],
        ),
      );
}