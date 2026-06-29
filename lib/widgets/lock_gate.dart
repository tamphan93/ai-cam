import 'package:flutter/material.dart';

import '../services/app_lock.dart';

/// Bọc toàn app: nếu bật khóa, yêu cầu xác thực Face ID/Touch ID khi mở app
/// và mỗi khi quay lại từ nền.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Khóa lại khi vào nền (sẽ yêu cầu xác thực khi quay lại).
      AppLock.isEnabled().then((on) {
        if (on && mounted) setState(() => _locked = true);
      });
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _maybeLock() async {
    if (await AppLock.isEnabled()) {
      setState(() => _locked = true);
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await AppLock.authenticate();
    _authenticating = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.white, size: 64),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Mở khóa'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
