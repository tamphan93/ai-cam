import 'package:flutter/material.dart';

import '../services/app_lock.dart';

/// Cài đặt: bật/tắt khóa app bằng Face ID / Touch ID.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enabled = false;
  bool _supported = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppLock.isEnabled();
    final supported = await AppLock.isSupported();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _supported = supported;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    // Khi bật, yêu cầu xác thực ngay để chắc chắn thiết bị mở khóa được.
    if (value) {
      final ok = await AppLock.authenticate();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Xác thực thất bại — chưa bật khóa'),
          ));
        }
        return;
      }
    }
    await AppLock.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock),
                  title: const Text('Khóa app bằng Face ID / Touch ID'),
                  subtitle: Text(_supported
                      ? 'Yêu cầu xác thực khi mở app'
                      : 'Thiết bị không hỗ trợ sinh trắc học / passcode'),
                  value: _enabled,
                  onChanged: _supported ? _toggle : null,
                ),
              ],
            ),
    );
  }
}
