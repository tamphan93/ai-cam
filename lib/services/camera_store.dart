import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/camera.dart';

/// Quản lý danh sách camera: metadata trong SharedPreferences, mật khẩu trong
/// Keychain (flutter_secure_storage). Cung cấp cho UI qua ChangeNotifier.
class CameraStore extends ChangeNotifier {
  CameraStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const _prefsKey = 'cameras_v1';
  static const _pwPrefix = 'cam_pw_';

  final FlutterSecureStorage _secure;
  final _uuid = const Uuid();

  final List<Camera> _cameras = [];
  List<Camera> get cameras => List.unmodifiable(_cameras);

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Nạp danh sách cam + mật khẩu tương ứng từ storage.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _cameras.clear();
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final m in list) {
        final cam = Camera.fromJson(m);
        cam.password = await _secure.read(key: _pwPrefix + cam.id) ?? '';
        _cameras.add(cam);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Camera? byId(String id) {
    for (final c in _cameras) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Camera> add({
    required String name,
    required String host,
    required String username,
    required String password,
    int rtspPort = 554,
    int onvifPort = 2020,
    bool flip180 = false,
  }) async {
    final cam = Camera(
      id: _uuid.v4(),
      name: name,
      host: host,
      username: username,
      password: password,
      rtspPort: rtspPort,
      onvifPort: onvifPort,
      flip180: flip180,
    );
    _cameras.add(cam);
    await _secure.write(key: _pwPrefix + cam.id, value: password);
    await _persist();
    notifyListeners();
    return cam;
  }

  Future<void> update(Camera cam) async {
    final i = _cameras.indexWhere((c) => c.id == cam.id);
    if (i < 0) return;
    _cameras[i] = cam;
    await _secure.write(key: _pwPrefix + cam.id, value: cam.password);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _cameras.removeWhere((c) => c.id == id);
    await _secure.delete(key: _pwPrefix + id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_cameras.map((c) => c.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }
}
