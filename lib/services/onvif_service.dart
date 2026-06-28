import 'package:easy_onvif/onvif.dart';
import 'package:easy_onvif/ptz.dart';
import 'package:flutter/foundation.dart';

import '../models/camera.dart';

enum PtzDir { up, down, left, right }

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

  void dispose() {
    _onvif = null;
    _profileToken = null;
  }
}
