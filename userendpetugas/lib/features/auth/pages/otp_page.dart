import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/route_constants.dart';
import '../../../core/auth_wrapper.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../../../utils/validators.dart';

// ============================================================
// Palette diambil dari src/css/otp.css agar tampilan konsisten
// dengan versi website. Tidak ada perubahan pada business logic.
// ============================================================
class _OtpColors {
  static const green = Color(0xFF16A34A); // judul & tombol utama
  static const teal = Color(0xFF0D9488); // focus / filled / link resend
  static const tealBg = Color(0xFFF0FDFA); // bg box saat terisi
  static const border = Color(0xFFCBD5E1); // border default box
  static const muted = Color(0xFF64748B); // subtitle & teks abu
  static const mutedLight = Color(0xFF94A3B8); // teks timer
  static const errorBg = Color(0xFFFEE2E2);
  static const errorText = Color(0xFFDC2626);
}

class OtpPage extends StatefulWidget {
  final String email;

  const OtpPage({super.key, required this.email});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _countdown = 60;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, RouteConstants.register);
      });
    }
    _startCountdown();

    // Listener fokus hanya untuk kebutuhan visual (border warna saat fokus),
    // meniru style ":focus" pada .otp-input di website. Tidak menyentuh logic.
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _countdown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown -= 1;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    // Allow alphanumeric characters and distribute pasted content across fields
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) {
      _controllers[index].clear();
      setState(() {}); // update tampilan box (hilangkan state "filled")
      return;
    }

    final chars = cleaned.split('');
    for (var i = 0; i < chars.length; i++) {
      final targetIndex = index + i;
      if (targetIndex < _controllers.length) {
        _controllers[targetIndex].text = chars[i];
      }
    }

    final nextIndex = index + chars.length;
    if (nextIndex < _focusNodes.length) {
      _focusNodes[nextIndex].requestFocus();
    } else {
      _focusNodes.last.unfocus();
    }

    setState(() {}); // update tampilan box (state "filled") — UI only
  }

  Future<void> _handlePaste(String? pasted) async {
    if (pasted == null || pasted.trim().isEmpty) return;
    final cleaned = pasted.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return;
    final chars = cleaned.split('');
    for (var i = 0; i < chars.length && i < _controllers.length; i++) {
      _controllers[i].text = chars[i];
    }
    final next = chars.length < _focusNodes.length ? chars.length : _focusNodes.length - 1;
    _focusNodes[next].requestFocus();
    setState(() {});
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _verifyOtp() async {
    setState(() {
      _errorMessage = null;
    });

    if (!Validators.isValidOtp(_otpCode)) {
      setState(() {
        _errorMessage = 'Masukkan 6 digit kode OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyRegister(
      email: widget.email,
      otp: _otpCode,
    );

    if (success) {
      final user = authProvider.user;
      var route = user != null ? getInitialRouteByRole(user) : RouteConstants.userDashboard;
      if (route == RouteConstants.login) {
        route = user != null && user.role.trim().toLowerCase() == 'driver'
            ? RouteConstants.driverDashboard
            : RouteConstants.userDashboard;
      }
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(route, (_) => false);
      }
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Verifikasi gagal';
      });
      _resetOtpFields();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetOtpFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
    setState(() {});
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendOtp(email: widget.email);

    if (success) {
      _startCountdown();
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Gagal mengirim ulang OTP';
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400; // mirip breakpoint 480px di CSS
    final cardPadding = isCompact ? 24.0 : 40.0;
    final boxHeight = isCompact ? 50.0 : 60.0;
    final boxFontSize = isCompact ? 22.0 : 28.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(cardPadding),
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---- Header ----
                          Text(
                            '🔐 Verifikasi Pendaftaran',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isCompact ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: _OtpColors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 15,
                                color: _OtpColors.muted,
                              ),
                              children: [
                                const TextSpan(text: 'Kami telah mengirim kode ke '),
                                TextSpan(
                                  text: widget.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),

                          // ---- Error message ----
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _OtpColors.errorBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _OtpColors.errorText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // ---- OTP grid (6 kolom fleksibel, gap 12) ----
                          Row(
                            children: List.generate(6, (index) {
                              final isFilled =
                                  _controllers[index].text.trim().isNotEmpty;
                              final isFocused = _focusNodes[index].hasFocus;

                              Color borderColor = _OtpColors.border;
                              Color bgColor = Colors.white;
                              if (isFilled) {
                                borderColor = _OtpColors.teal;
                                bgColor = _OtpColors.tealBg;
                              }
                              if (isFocused) {
                                borderColor = _OtpColors.teal;
                              }

                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index < 5 ? 12 : 0,
                                  ),
                                  child: GestureDetector(
                                    onLongPress: () async {
                                      final data =
                                          await Clipboard.getData('text/plain');
                                      await _handlePaste(data?.text);
                                    },
                                    child: SizedBox(
                                      height: boxHeight,
                                      child: TextField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        keyboardType: TextInputType.text,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[A-Za-z0-9]')),
                                        ],
                                        style: TextStyle(
                                          fontSize: boxFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          filled: true,
                                          fillColor: bgColor,
                                          contentPadding: EdgeInsets.zero,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: borderColor, width: 2),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: borderColor, width: 2),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: _OtpColors.teal, width: 2),
                                          ),
                                        ),
                                        onChanged: (value) =>
                                            _onOtpChanged(index, value),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 28),

                          // ---- Tombol Verifikasi ----
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _OtpColors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Verifikasi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ---- Resend ----
                          Center(
                            child: _countdown > 0
                                ? Text(
                                    'Kirim ulang dalam ${_countdown}s',
                                    style: const TextStyle(
                                      color: _OtpColors.mutedLight,
                                      fontSize: 14,
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _isLoading ? null : _resendOtp,
                                    style: TextButton.styleFrom(
                                      foregroundColor: _OtpColors.teal,
                                    ),
                                    child: const Text(
                                      'Kirim Ulang Kode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 12),

                          // ---- Kembali ----
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                  context, RouteConstants.register);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _OtpColors.muted,
                            ),
                            child: const Text(
                              '← Kembali ke Pendaftaran',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}