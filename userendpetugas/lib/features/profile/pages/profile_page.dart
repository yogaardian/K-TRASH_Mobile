import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../utils/profile_photo_utils.dart';
import '../../../utils/secure_storage_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _MessageType { success, danger, info }

class _ProfileMessage {
  final _MessageType type;
  final String text;
  _ProfileMessage(this.type, this.text);
}

// Design Tokens — disamakan persis dengan CSS website (profile page)
class _ProfileColors {
  // Text / neutral
  static const heading = Color(0xFF0F172A); // slate-900
  static const label = Color(0xFF1E293B); // slate-800
  static const muted = Color(0xFF64748B); // slate-500
  static const border = Color(0xFFE2E8F0); // slate-200
  static const pageBg = Color(0xFFF8FAFC); // slate-50

  // Brand green
  static const primary = Color(0xFF16A34A); // green-600
  static const primaryHover = Color(0xFF15803D); // green-700
  static const avatarGradientStart = Color(0xFF22C55E); // green-500
  static const avatarGradientEnd = Color(0xFF16A34A); // green-600

  // Secondary (gray)
  static const secondaryBg = Color(0xFFE2E8F0);
  static const secondaryFg = Color(0xFF475569); // slate-600

  // Danger (red)
  static const danger = Color(0xFFEF4444);
  static const dangerHover = Color(0xFFDC2626);

  // Message banners — exact hex from website CSS
  static const successBg = Color(0xFFDCFCE7);
  static const successFg = Color(0xFF166534);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerFg = Color(0xFFB91C1C);
  static const infoBg = Color(0xFFDBEAFE);
  static const infoFg = Color(0xFF1E40AF);
}

/// Breakpoint helper — meniru responsif CSS website
class _Bp {
  final bool isSmall; // setara media query <=480px
  final bool isMedium; // setara media query <=768px
  const _Bp(this.isSmall, this.isMedium);

  factory _Bp.of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Bp(w <= 480, w <= 768);
  }

  double pick({
    required double small,
    required double medium,
    required double large,
  }) {
    if (isSmall) return small;
    if (isMedium) return medium;
    return large;
  }
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _profilePhotoBase64;
  _ProfileMessage? _message;
  bool _loading = false;
  bool _mounted = true;
  int? _currentUserId;

  static const int _maxPhotoBytes = 5 * 1024 * 1024; // 5MB
  static const String _prefsKeyPrefix = 'user_profile_';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _mounted = false;
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _profilePrefsKey(int userId) => '$_prefsKeyPrefix$userId';

  int? _parseUserId(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['user_id'] ?? data['userId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Map<String, dynamic>? _parseStoredUserData(String userJson) {
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } on FormatException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  // STORAGE & API — Robust multi-layer loading
  // Layer 1: SecureStorageHelper → Layer 2: SharedPrefs → Layer 3: Backend
  // -----------------------------------------------------------------------
  Future<void> _loadProfile() async {
    // Step 1: Load dari SecureStorageHelper (account data terenkripsi)
    try {
      final userJson = await SecureStorageHelper.getUserData();
      if (userJson != null) {
        final accountData = _parseStoredUserData(userJson);
        if (accountData != null) {
          _currentUserId = _parseUserId(accountData);
          if (mounted) {
            setState(() {
              _nameController.text = accountData['nama']?.toString() ?? '';
              _phoneController.text =
                  accountData['nomor_hp']?.toString() ??
                  accountData['phoneNumber']?.toString() ??
                  accountData['phone']?.toString() ??
                  '';
              _profilePhotoBase64 =
                  accountData['photo']?.toString() ??
                  accountData['profile_photo']?.toString() ??
                  accountData['profilePhoto']?.toString();
            });
          }
        }
      }
    } catch (_) {
      // ignore broken secure storage payloads
    }

    // Step 2: Load dari SharedPreferences (fallback untuk metadata)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _currentUserId != null
          ? _profilePrefsKey(_currentUserId!)
          : _prefsKeyPrefix + 'default';
      final jsonStr = prefs.getString(key) ?? prefs.getString('user_profile');
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _nameController.text = map['name']?.toString().isNotEmpty == true
                ? map['name']!.toString()
                : _nameController.text;
            _phoneController.text =
                map['phoneNumber']?.toString().isNotEmpty == true
                ? map['phoneNumber']!.toString()
                : _phoneController.text;
            _profilePhotoBase64 =
                map['photo']?.toString() ??
                map['profile_photo']?.toString() ??
                map['profilePhoto']?.toString() ??
                _profilePhotoBase64;
          });
        }
      }
    } catch (_) {
      // ignore parse errors
    }

    // Step 3: Fetch dari backend untuk data fresh
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          _currentUserId ?? int.tryParse(prefs.getString('userId') ?? '');
      final token = await SecureStorageHelper.getToken();

      if (userId != null && token != null) {
        try {
          final profileData = await ApiService.getUserProfile(userId, token);

          if (!_mounted) return;
          setState(() {
            _nameController.text =
                profileData['nama']?.toString() ??
                profileData['name']?.toString() ??
                _nameController.text;
            _phoneController.text =
                profileData['nomor_hp']?.toString() ??
                profileData['phone']?.toString() ??
                _phoneController.text;
            _profilePhotoBase64 =
                profileData['profile_photo']?.toString() ??
                profileData['photo']?.toString() ??
                _profilePhotoBase64;
          });

          // Simpan metadata ke local storage (BUKAN foto - terlalu besar)
          await _saveProfileToStorage();
          return;
        } catch (e) {
          debugPrint('Error loading profile from backend: $e');
          // Fallback ke local storage jika backend error
        }
      }
    } catch (e) {
      debugPrint('Error in _loadProfile backend step: $e');
    }
  }

  Future<void> _saveProfileToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserId != null
        ? _profilePrefsKey(_currentUserId!)
        : _prefsKeyPrefix + 'default';
    await prefs.setString(
      key,
      jsonEncode({
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        // TIDAK menyimpan foto - base64 terlalu besar, melebihi quota localStorage
      }),
    );

    // Juga simpan ke format lama untuk compatibility
    await prefs.setString('nama', _nameController.text);
    await prefs.setString('nomor_hp', _phoneController.text);

    // Update SecureStorageHelper jika ada
    try {
      final authUserJson = await SecureStorageHelper.getUserData();
      if (authUserJson != null) {
        final authMap = jsonDecode(authUserJson) as Map<String, dynamic>;
        authMap['nama'] = _nameController.text;
        authMap['nomor_hp'] = _phoneController.text;
        // Foto dari backend saja, jangan simpan local
        await SecureStorageHelper.saveUserData(jsonEncode(authMap));
      }
    } catch (_) {
      // ignore if secure storage update fails
    }
  }

  // API — Update user profile ke backend
  Future<void> _updateUserOnServer({
    required int? userId,
    required String nama,
    required String nomorHp,
    String? profilePhoto,
  }) async {
    if (userId == null) return;

    final token = await SecureStorageHelper.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak tersedia. Silakan login kembali.');
    }

    try {
      final response = await ApiService.updateUserProfile(userId, {
        'nama': nama,
        'nomor_hp': nomorHp,
        if (profilePhoto != null) 'profile_photo': profilePhoto,
      }, token);

      if (response['status'] != 'success') {
        throw Exception(response['message'] ?? 'Gagal menyimpan profil');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ACTIONS
  Future<void> _handleSave() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          _currentUserId ?? int.tryParse(prefs.getString('userId') ?? '');

      await _updateUserOnServer(
        userId: userId,
        nama: _nameController.text,
        nomorHp: _phoneController.text,
        profilePhoto: _profilePhotoBase64,
      );
      await _saveProfileToStorage();

      if (!_mounted) return;
      setState(() {
        _message = _ProfileMessage(
          _MessageType.success,
          '✓ Profil berhasil disimpan.',
        );
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (_mounted && _message?.type == _MessageType.success) {
          setState(() => _message = null);
        }
      });
    } on Exception catch (e) {
      if (_mounted) {
        setState(() {
          _message = _ProfileMessage(
            _MessageType.danger,
            'Gagal menyimpan profil: ${e.toString().replaceAll('Exception: ', '')}',
          );
        });
      }
    } finally {
      if (_mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePhotoUpload() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > _maxPhotoBytes) {
      setState(() {
        _message = _ProfileMessage(
          _MessageType.danger,
          'Ukuran foto terlalu besar (maksimal 5MB sebelum dikodekan).',
        );
      });
      return;
    }

    final base64Str = base64Encode(bytes);
    setState(() {
      _profilePhotoBase64 = base64Str;
      _message = _ProfileMessage(
        _MessageType.info,
        'Foto dipilih. Klik Simpan untuk menyimpan.',
      );
    });
  }

  Future<void> _handleRemovePhoto() async {
    setState(() => _profilePhotoBase64 = null);
    await _saveProfileToStorage();
    setState(() {
      _message = _ProfileMessage(_MessageType.info, 'Foto profil dihapus.');
    });
  }

  Future<void> _handleReset() async {
    await _loadProfile();
    setState(() {
      _message = _ProfileMessage(_MessageType.info, 'Perubahan dibatalkan.');
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['token', 'userId', 'nama', 'role']) {
      await prefs.remove(key);
    }
    await SecureStorageHelper.deleteToken();
    await SecureStorageHelper.deleteUserData();
    if (!_mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus akun? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: _ProfileColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await SecureStorageHelper.clearAll();
      if (!_mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final bp = _Bp.of(context);

    return Scaffold(
      backgroundColor: _ProfileColors.pageBg,
      appBar: AppBar(
        backgroundColor: _ProfileColors.pageBg,
        elevation: 0,
        foregroundColor: _ProfileColors.heading,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pengaturan Profil',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _ProfileColors.heading,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(bp.pick(small: 12, medium: 16, large: 20)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_message != null) _buildMessageBanner(_message!),
                  if (_message != null)
                    SizedBox(height: bp.pick(small: 10, medium: 12, large: 14)),
                  _buildProfileSummaryCard(bp),
                  SizedBox(height: bp.pick(small: 12, medium: 16, large: 16)),
                  _buildEditFormCard(bp),
                  SizedBox(height: bp.pick(small: 12, medium: 16, large: 16)),
                  _buildMoreOptionsCard(bp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBanner(_ProfileMessage message) {
    Color bg;
    Color fg;
    switch (message.type) {
      case _MessageType.success:
        bg = _ProfileColors.successBg;
        fg = _ProfileColors.successFg;
        break;
      case _MessageType.danger:
        bg = _ProfileColors.dangerBg;
        fg = _ProfileColors.dangerFg;
        break;
      case _MessageType.info:
        bg = _ProfileColors.infoBg;
        fg = _ProfileColors.infoFg;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  Widget _card({required Widget child, required _Bp bp}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(bp.pick(small: 16, medium: 20, large: 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          bp.pick(small: 16, medium: 20, large: 22),
        ),
        boxShadow: [
          BoxShadow(
            color: _ProfileColors.heading.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAvatar(double size) {
    final imageProvider = buildProfileImageProvider(_profilePhotoBase64);
    if (imageProvider != null) {
      return ClipOval(
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _ProfileColors.avatarGradientStart,
            _ProfileColors.avatarGradientEnd,
          ],
        ),
      ),
      child: Icon(Icons.person, color: Colors.white, size: size * 0.5),
    );
  }

  Widget _buildProfileSummaryCard(_Bp bp) {
    final avatarSize = bp.pick(small: 70, medium: 90, large: 100);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatar(avatarSize),
        SizedBox(width: bp.pick(small: 12, medium: 16, large: 20)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.isEmpty ? '-' : _nameController.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ProfileColors.heading,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _phoneController.text.isEmpty ? '-' : _phoneController.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: _ProfileColors.muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return _card(
      bp: bp,
      child: bp.isMedium
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(avatarSize),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isEmpty ? '-' : _nameController.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ProfileColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _phoneController.text.isEmpty
                          ? '-'
                          : _phoneController.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ProfileColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : header,
    );
  }

  Widget _buildEditFormCard(_Bp bp) {
    return _card(
      bp: bp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profil',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _ProfileColors.heading,
            ),
          ),
          SizedBox(height: bp.pick(small: 14, medium: 16, large: 18)),

          Text('Foto Profil', style: _labelStyle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: bp.isSmall ? double.infinity : 200,
                child: OutlinedButton.icon(
                  onPressed: _handlePhotoUpload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ProfileColors.label,
                    side: const BorderSide(
                      color: _ProfileColors.border,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.upload),
                  label: const Text('Pilih Foto'),
                ),
              ),
              if (_profilePhotoBase64 != null)
                TextButton(
                  onPressed: _handleRemovePhoto,
                  style: TextButton.styleFrom(
                    foregroundColor: _ProfileColors.danger,
                  ),
                  child: const Text('Hapus'),
                ),
            ],
          ),
          if (_profilePhotoBase64 != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Preview:',
              style: TextStyle(fontSize: 13, color: _ProfileColors.muted),
            ),
            const SizedBox(height: 6),
            () {
              final imageProvider = buildProfileImageProvider(
                _profilePhotoBase64,
              );
              if (imageProvider == null) {
                return const SizedBox.shrink();
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _ProfileColors.border, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image(
                    image: imageProvider,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }(),
          ],
          SizedBox(height: bp.pick(small: 16, medium: 18, large: 20)),

          Text('Nama Lengkap', style: _labelStyle()),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _nameController,
            hint: 'Masukkan nama lengkap',
          ),
          const SizedBox(height: 14),

          Text('Nomor HP', style: _labelStyle()),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _phoneController,
            hint: 'Masukkan nomor HP',
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: bp.pick(small: 18, medium: 20, large: 20)),

          bp.isSmall
              ? Column(
                  children: [
                    _primaryButton(
                      label: 'Simpan Perubahan',
                      onPressed: _loading ? null : _handleSave,
                      loading: _loading,
                    ),
                    const SizedBox(height: 10),
                    _secondaryButton(label: 'Reset', onPressed: _handleReset),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _primaryButton(
                        label: 'Simpan Perubahan',
                        onPressed: _loading ? null : _handleSave,
                        loading: _loading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _secondaryButton(
                        label: 'Reset',
                        onPressed: _handleReset,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsCard(_Bp bp) {
    return _card(
      bp: bp,
      child: Column(
        children: [
          _dangerButton(
            label: 'Hapus Akun',
            onPressed: () => _handleDeleteAccount(),
          ),
          const SizedBox(height: 10),
          _dangerButton(label: 'Keluar', onPressed: () => _handleLogout()),
        ],
      ),
    );
  }

  TextStyle _labelStyle() => const TextStyle(
    fontWeight: FontWeight.w600,
    color: _ProfileColors.label,
    fontSize: 14,
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ProfileColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ProfileColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ProfileColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style:
          ElevatedButton.styleFrom(
            backgroundColor: _ProfileColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _ProfileColors.primary.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ).copyWith(
            overlayColor: MaterialStateProperty.all(
              _ProfileColors.primaryHover.withOpacity(0.1),
            ),
          ),
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _ProfileColors.secondaryBg,
        foregroundColor: _ProfileColors.secondaryFg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _dangerButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: _ProfileColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: MaterialStateProperty.all(
                _ProfileColors.dangerHover.withOpacity(0.15),
              ),
            ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
