import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý khóa app bằng sinh trắc học (Face ID / Touch ID).
class AppLock {
  static const _key = 'lock_enabled';
  static final _auth = LocalAuthentication();

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Thiết bị có hỗ trợ khóa (sinh trắc học hoặc passcode) không.
  static Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('local_auth isDeviceSupported lỗi: $e');
      return false;
    }
  }

  /// Yêu cầu xác thực. Cho phép fallback sang passcode của máy.
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Mở khóa ứng dụng để xem camera',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('local_auth authenticate lỗi: $e');
      return false;
    }
  }
}
