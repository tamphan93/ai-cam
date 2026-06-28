import 'package:easy_onvif/onvif.dart';
import 'package:easy_onvif/ptz.dart';
import 'package:flutter/foundation.dart';

import '../models/camera.dart';

enum PtzDir { up, down, left, right }

/// Một vị trí PTZ đã lưu trên camera.
class PtzPreset {
  PtzPreset({required this.token, required this.name});
  final String token;
  final String name;
}

/// Bao bọc ONVIF cho một camera: kết nối, lấy profile token và điều khiển PTZ.
///
/// LƯU Ý: API của gói `easy_onvif` thay đổi theo version. Nếu build báo lỗi
/// ở phần PTZ, hãy đối chiếu chữ ký `continuousMove` / `stop` với version
/// `easy_onvif` mà bạn cài (xem README, mục "PTZ / ONVIF").
class OnvifService {
  Onvif? _onvif;
  String? _profileToken;

  bool get isConnected => _onvif != null && _profileToken != null;

  Future<bool> connect(Camera cam) async {
    try {
      _onvif = await Onvif.connect(
        host: cam.onvifHost,
        username: cam.username,
        password: cam.password,
      );
      final profiles = await _onvif!.media.getProfiles();
      if (profiles.isEmpty) return false;
      _profileToken = profiles.first.token;
      return true;
    } catch (e) {
      debugPrint('ONVIF connect lỗi: $e');
      _onvif = null;
      _profileToken = null;
      return false;
    }
  }

  /// Tốc độ pan/tilt cho continuousMove (-1.0..1.0). C200 chỉ pan/tilt.
  static const _speed = 0.6;

  Future<void> move(PtzDir dir) async {
    if (!isConnected) return;
    double x = 0, y = 0;
    switch (dir) {
      case PtzDir.up:
        y = _speed;
        break;
      case PtzDir.down:
        y = -_speed;
        break;
      case PtzDir.left:
        x = -_speed;
        break;
      case PtzDir.right:
        x = _speed;
        break;
    }
    try {
      await _onvif!.ptz.continuousMove(
        _profileToken!,
        velocity: PtzPosition(panTilt: Vector2D(x: x, y: y)),
      );
    } catch (e) {
      debugPrint('PTZ move lỗi: $e');
    }
  }

  Future<void> stop() async {
    if (!isConnected) return;
    try {
      await _onvif!.ptz.stop(_profileToken!);
    } catch (e) {
      debugPrint('PTZ stop lỗi: $e');
    }
  }

  /// Danh sách preset đã lưu trên camera (token + tên).
  Future<List<PtzPreset>> getPresets() async {
    if (!isConnected) return [];
    try {
      final presets = await _onvif!.ptz.getPresets(_profileToken!);
      return [
        for (final p in presets)
          PtzPreset(token: p.token ?? '', name: p.name ?? p.token ?? ''),
      ];
    } catch (e) {
      debugPrint('PTZ getPresets lỗi: $e');
      return [];
    }
  }

  /// Quay camera về một preset.
  Future<void> gotoPreset(String presetToken) async {
    if (!isConnected) return;
    try {
      await _onvif!.ptz.gotoPreset(_profileToken!, presetToken);
    } catch (e) {
      debugPrint('PTZ gotoPreset lỗi: $e');
    }
  }

  /// Lưu vị trí hiện tại thành một preset mới. Trả về true nếu thành công.
  Future<bool> savePreset(String name) async {
    if (!isConnected) return false;
    try {
      await _onvif!.ptz.setPreset(_profileToken!, name);
      return true;
    } catch (e) {
      debugPrint('PTZ setPreset lỗi: $e');
      return false;
    }
  }

  void dispose() {
    _onvif = null;
    _profileToken = null;
  }
}
