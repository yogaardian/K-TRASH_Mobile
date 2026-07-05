import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/route_constants.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../../../utils/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agree = false;
  bool _isLoading = false;
  String? _errorMessage;

  // ============================================================
  // LOGIC DI BAWAH INI TIDAK DIUBAH SAMA SEKALI DARI VERSI ASLI
  // ============================================================
  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmController.text;

    if (!Validators.isRequired(name)) {
      setState(() {
        _errorMessage = 'Nama lengkap harus diisi';
      });
      return;
    }

    if (!Validators.isRequired(email)) {
      setState(() {
        _errorMessage = 'Email harus diisi';
      });
      return;
    }

    if (!Validators.isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Format email tidak valid';
      });
      return;
    }

    if (!Validators.isRequired(phone)) {
      setState(() {
        _errorMessage = 'Nomor HP harus diisi';
      });
      return;
    }

    if (!Validators.isValidPhoneNumber(phone)) {
      setState(() {
        _errorMessage = 'Nomor HP harus 10-13 digit';
      });
      return;
    }

    if (!Validators.isRequired(password)) {
      setState(() {
        _errorMessage = 'Password harus diisi';
      });
      return;
    }

    if (!Validators.isValidPassword(password)) {
      setState(() {
        _errorMessage = 'Password minimal 6 karakter';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Password dan konfirmasi password tidak cocok';
      });
      return;
    }

    if (!_agree) {
      setState(() {
        _errorMessage = 'Anda harus setuju dengan Syarat & Ketentuan';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      nama: name,
      email: email,
      password: password,
      role: 'user',
      nomorHp: phone,
    );

    if (success) {
      if (mounted) {
        Navigator.pushNamed(context, RouteConstants.otp, arguments: email);
      }
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Pendaftaran gagal';
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
  // ============================================================
  // AKHIR BAGIAN LOGIC YANG TIDAK DIUBAH
  // ============================================================

  // --- UI helper: field input gaya website (rounded 12, bg abu muda) ---
  Widget _buildField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool isPassword = false,
    bool isHidden = false,
    VoidCallback? toggle,
    TextInputType? keyboardType,
  }) {
    const green = Color(0xFF2E7D32);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isHidden : false,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          prefixIcon: icon != null
              ? Icon(icon, color: green, size: 20)
              : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isHidden ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: toggle,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    const lightGreen = Color(0xFF8BC34A);

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
          // Overlay (mirip .overlay website: putih 95%)
          Container(
            color: Colors.white.withOpacity(0.95),
          ),
          SafeArea(
            child: Column(
              children: [
                // ===== TOP NAVBAR (mirip .top-navbar website) =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.eco, color: green, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'K-Trash',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, RouteConstants.login);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Daftar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== CARD AREA (scrollable, tidak dipaksa minHeight) =====
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title gradient
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [green, lightGreen],
                                ).createShader(bounds),
                                child: const Text(
                                  'Buat Akun Baru',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white, // ditimpa shader
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bergabung dengan K-Trash dan mulai\nkelola sampah dengan lebih mudah.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF666666),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (_errorMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEEEE),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFFCCCC)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFCC3333),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],

                              _buildField(
                                'Nama Lengkap',
                                _nameController,
                                icon: Icons.person_outline,
                              ),
                              _buildField(
                                'Email',
                                _emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _buildField(
                                'Nomor HP',
                                _phoneController,
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildField(
                                'Password',
                                _passwordController,
                                icon: Icons.lock_outline,
                                isPassword: true,
                                isHidden: !_showPassword,
                                toggle: () =>
                                    setState(() => _showPassword = !_showPassword),
                              ),
                              _buildField(
                                'Konfirmasi Password',
                                _confirmController,
                                icon: Icons.lock_outline,
                                isPassword: true,
                                isHidden: !_showConfirmPassword,
                                toggle: () => setState(
                                    () => _showConfirmPassword = !_showConfirmPassword),
                              ),

                              // Checkbox
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _agree,
                                      activeColor: green,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) {
                                        setState(() {
                                          _agree = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF666666),
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(text: 'Saya setuju dengan '),
                                            TextSpan(
                                              text: 'Syarat & Ketentuan',
                                              style: TextStyle(
                                                color: green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(text: ' dan '),
                                            TextSpan(
                                              text: 'Kebijakan Privasi',
                                              style: TextStyle(
                                                color: green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Tombol gradient
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [lightGreen, green],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: green.withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _isLoading ? null : _handleRegister,
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(
                                                    Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Daftar Sekarang →',
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

                              const SizedBox(height: 16),

                              // Bottom login
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Sudah punya akun?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(context, RouteConstants.login);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Text(
                                        'Login Sekarang',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: green,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}