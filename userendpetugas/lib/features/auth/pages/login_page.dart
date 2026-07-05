import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../../constants/route_constants.dart';
import '../../../core/auth_wrapper.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../../../utils/validators.dart';

// ==================== BRAND COLORS (sesuai CSS website) ====================
const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kAccentGreen = Color(0xFF8BC34A);
const Color kInputFill = Color(0xFFF8F8F8);
const Color kInputBorder = Color(0xFFE0E0E0);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  // UI-only state (tidak dikirim ke backend) — setara "Ingat Saya" di website
  bool _rememberMe = false;
  String? _errorMessage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb && _googleWebClientId.isNotEmpty
        ? _googleWebClientId
        : null,
  );

  // ==================== LOGIC TIDAK DIUBAH ====================

  Future<void> _handleLogin() async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!Validators.isRequired(email) || !Validators.isRequired(password)) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Isi semua data';
        _isLoading = false;
      });
      return;
    }

    if (!Validators.isValidEmail(email)) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Format email tidak valid';
        _isLoading = false;
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(email: email, password: password);

    if (!mounted) return;

    if (success) {
      final user = authProvider.user;
      var route = user != null
          ? getInitialRouteByRole(user)
          : RouteConstants.userDashboard;
      if (route == RouteConstants.login) {
        route = user != null && user.role.trim().toLowerCase() == 'driver'
            ? RouteConstants.driverDashboard
            : RouteConstants.userDashboard;
      }
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(route, (_) => false);
    } else {
      final pendingEmail = authProvider.pendingVerificationEmail;
      if (pendingEmail != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Verifikasi Email'),
            content: const Text(
              'Email Anda belum diverifikasi. Cek email Anda untuk kode OTP dan lengkapi pendaftaran.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (mounted) {
                    Navigator.pushNamed(
                      context,
                      RouteConstants.otp,
                      arguments: pendingEmail,
                    );
                  }
                },
                child: const Text('Lanjut ke Verifikasi'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Login gagal';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Google sign-in dibatalkan';
          _isLoading = false;
        });
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Gagal mendapatkan token Google';
          _isLoading = false;
        });
        return;
      }

      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.googleLogin(credential: idToken);

      if (!mounted) return;
      if (success) {
        final user = authProvider.user;
        var route = user != null
            ? getInitialRouteByRole(user)
            : RouteConstants.userDashboard;
        if (route == RouteConstants.login) {  
          route = user != null && user.role.trim().toLowerCase() == 'driver'
              ? RouteConstants.driverDashboard
              : RouteConstants.userDashboard;
        }
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(route, (_) => false);
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Google login gagal';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Google login gagal. Silakan coba lagi.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==================== UI HELPERS (visual only, no logic) ====================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
      prefixIcon: Icon(icon, color: kPrimaryGreen, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: kInputFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kInputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
      ),
    );
  }

  // ==================== UI (MIGRASI DARI WEBSITE) ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay — setara rgba(255,255,255,0.95) di website
          Container(color: Colors.white.withOpacity(0.95)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ---------- TOP NAVBAR ----------
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/logo.png',
                                      height: 32,
                                      width: 32,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(
                                        Icons.recycling,
                                        color: kPrimaryGreen,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'K-Trash',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: kPrimaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Switch Login / Daftar — setara .auth-switch
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0D000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Login',
                                          style: TextStyle(
                                            color: kPrimaryGreen,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => Navigator.pushNamed(
                                                  context,
                                                  RouteConstants.register,
                                                ),
                                        child: const Text(
                                          'Daftar',
                                          style: TextStyle(
                                            color: Color(0xFF666666),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ---------- LOGIN CARD ----------
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 420),
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Title gradient — setara .login-title span
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [kPrimaryGreen, kAccentGreen],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Selamat Datang',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Masuk ke akun K-Trash Anda dan mulai kelola sampah dengan lebih mudah.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_errorMessage != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEEEEE),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFFFCCCC),
                                        ),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFCC3333),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                  // EMAIL
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _inputDecoration(
                                      hint: 'Masukkan Email',
                                      icon: Icons.mail_outline,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // PASSWORD
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    decoration: _inputDecoration(
                                      hint: 'Masukkan Password',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                          color: const Color(0xFF666666),
                                        ),
                                        onPressed: () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // REMEMBER ME + LUPA PASSWORD
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              activeColor: kPrimaryGreen,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              onChanged: (val) => setState(
                                                () => _rememberMe =
                                                    val ?? false,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Ingat Saya',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        'Lupa Password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: kPrimaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // SUBMIT — gradient setara .login-submit-btn
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [kAccentGreen, kPrimaryGreen],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: kPrimaryGreen.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: _isLoading
                                              ? null
                                              : _handleLogin,
                                          child: Center(
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Masuk Sekarang',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // DIVIDER "ATAU"
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'ATAU',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // GOOGLE SIGN-IN
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                      icon: const Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Colors.black87,
                                      ),
                                      label: const Text(
                                        'Masuk dengan Google',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // BOTTOM REGISTER
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Belum punya akun?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          RouteConstants.register,
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Daftar Sekarang',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: kPrimaryGreen,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}