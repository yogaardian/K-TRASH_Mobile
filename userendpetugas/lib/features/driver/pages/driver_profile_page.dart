import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:user/services/api_service.dart';
import 'package:user/utils/profile_photo_utils.dart';
import 'package:user/utils/secure_storage_helper.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

enum _MessageType { success, danger, info }

class _ProfileMessage {
  final _MessageType type;
  final String text;

  const _ProfileMessage(this.type, this.text);
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _profilePhotoBase64;
  _ProfileMessage? _message;
  bool _loading = false;
  bool _mounted = true;
  int? _currentUserId;

  static const int _maxPhotoBytes = 5 * 1024 * 1024;
  static const String _prefsKeyPrefix = 'petugas_profile_';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _mounted = false;
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userJson = await SecureStorageHelper.getUserData();
      if (userJson != null) {
        final accountData = _parseStoredUserData(userJson);
        if (accountData != null) {
          _currentUserId = _parseUserId(accountData);
          if (mounted) {
            setState(() {
              _nameController.text = accountData['nama']?.toString() ?? '';
              _emailController.text = accountData['email']?.toString() ?? '';
              _phoneController.text =
                  accountData['nomor_hp']?.toString() ??
                  accountData['phoneNumber']?.toString() ??
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

    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserId != null
        ? _profilePrefsKey(_currentUserId!)
        : _prefsKeyPrefix + 'default';
    final jsonStr = prefs.getString(key) ?? prefs.getString('petugas_profile');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _nameController.text = map['name']?.toString().isNotEmpty == true
                ? map['name']!.toString()
                : _nameController.text;
            _emailController.text = map['email']?.toString().isNotEmpty == true
                ? map['email']!.toString()
                : _emailController.text;
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
      } catch (_) {
        // ignore parse errors
      }
    }
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

  Future<void> _saveProfileToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentUserId != null
        ? _profilePrefsKey(_currentUserId!)
        : _prefsKeyPrefix + 'default';
    await prefs.setString(
      key,
      jsonEncode({
        'name': _nameController.text,
        'email': _emailController.text,
        'phoneNumber': _phoneController.text,
        // TIDAK menyimpan foto - base64 terlalu besar, melebihi quota localStorage
      }),
    );

    final authUserJson = await SecureStorageHelper.getUserData();
    if (authUserJson != null) {
      final authMap = jsonDecode(authUserJson) as Map<String, dynamic>;
      authMap['nama'] = _nameController.text;
      authMap['email'] = _emailController.text;
      authMap['nomor_hp'] = _phoneController.text;
      // Foto dari backend saja, jangan simpan local
      await SecureStorageHelper.saveUserData(jsonEncode(authMap));
    }
  }

  Future<void> _updateUserOnServer({
    required int? userId,
    required String nama,
    required String nomorHp,
    String? profilePhoto,
  }) async {
    if (userId == null) return;

    final token = await SecureStorageHelper.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak tersedia');
    }

    final response = await ApiService.updateUserProfile(userId, {
      'nama': nama,
      'nomor_hp': nomorHp,
      if (profilePhoto != null) 'profile_photo': profilePhoto,
    }, token);

    if (response['status'] != 'success') {
      throw Exception(response['message'] ?? 'Gagal mengirim data profil');
    }
  }

  Future<void> _handleSave() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = int.tryParse(prefs.getString('userId') ?? '');

      await _updateUserOnServer(
        userId: userId,
        nama: _nameController.text,
        nomorHp: _phoneController.text,
        profilePhoto: _profilePhotoBase64,
      );
      await _saveProfileToStorage();

      if (!_mounted) return;
      setState(() {
        _message = const _ProfileMessage(
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
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      setState(() {
        _message = const _ProfileMessage(
          _MessageType.danger,
          'Ukuran foto terlalu besar (maksimal 5MB sebelum dikodekan).',
        );
      });
      return;
    }

    setState(() {
      _profilePhotoBase64 = base64Encode(bytes);
      _message = const _ProfileMessage(
        _MessageType.info,
        'Foto dipilih. Klik Simpan untuk menyimpan.',
      );
    });
  }

  Future<void> _handleRemovePhoto() async {
    setState(() => _profilePhotoBase64 = null);
    await _saveProfileToStorage();
    setState(() {
      _message = const _ProfileMessage(
        _MessageType.info,
        'Foto profil dihapus.',
      );
    });
  }

  Future<void> _handleReset() async {
    await _loadProfile();
    setState(() {
      _message = const _ProfileMessage(
        _MessageType.info,
        'Perubahan dibatalkan.',
      );
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['token', 'userId', 'nama', 'role']) {
      await prefs.remove(key);
    }
    await SecureStorageHelper.deleteToken();
    await SecureStorageHelper.deleteUserData();
    if (!mounted) return;
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await SecureStorageHelper.clearAll();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildAvatar() {
    final imageProvider = buildProfileImageProvider(_profilePhotoBase64);
    if (imageProvider != null) {
      return CircleAvatar(radius: 32, backgroundImage: imageProvider);
    }

    return const CircleAvatar(
      radius: 32,
      backgroundColor: Color(0xFF9CA3AF),
      child: Icon(Icons.person, color: Colors.white, size: 32),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMessageBanner(_ProfileMessage message) {
    Color bg;
    Color fg;
    switch (message.type) {
      case _MessageType.success:
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF1E7E34);
        break;
      case _MessageType.danger:
        bg = const Color(0xFFFDECEA);
        fg = const Color(0xFFB3261E);
        break;
      case _MessageType.info:
        bg = const Color(0xFFE8F0FE);
        fg = const Color(0xFF1A56DB);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message.text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildProfileSummaryCard() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty ? '-' : _nameController.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _emailController.text.isEmpty ? '-' : _emailController.text,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _phoneController.text.isEmpty ? '-' : _phoneController.text,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditFormCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profil',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Foto Profil',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handlePhotoUpload,
                  icon: const Icon(Icons.upload),
                  label: const Text('Pilih Foto'),
                ),
              ),
              if (_profilePhotoBase64 != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _handleRemovePhoto,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus'),
                ),
              ],
            ],
          ),
          if (_profilePhotoBase64 != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Preview:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
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
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: imageProvider,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              );
            }(),
          ],
          const SizedBox(height: 18),
          const Text(
            'Nama Lengkap',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Masukkan nama lengkap',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Masukkan email',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          const Text('Nomor HP', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Masukkan nomor HP',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleReset,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsCard() {
    return _card(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleDeleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Hapus Akun'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Profil Petugas'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_message != null) _buildMessageBanner(_message!),
              if (_message != null) const SizedBox(height: 12),
              _buildProfileSummaryCard(),
              const SizedBox(height: 16),
              _buildEditFormCard(),
              const SizedBox(height: 16),
              _buildMoreOptionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
