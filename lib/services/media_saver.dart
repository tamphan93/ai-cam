import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// Lưu ảnh chụp / clip quay được vào thư viện ảnh (Photos).
class MediaSaver {
  static const _album = 'Tapo C200';

  /// Xin quyền ghi vào Photos (iOS: NSPhotoLibraryAddUsageDescription).
  static Future<bool> ensureAccess() async {
    try {
      if (await Gal.hasAccess(toAlbum: true)) return true;
      return await Gal.requestAccess(toAlbum: true);
    } catch (e) {
      debugPrint('Gal access lỗi: $e');
      return false;
    }
  }

  static Future<bool> saveImageBytes(Uint8List bytes) async {
    if (!await ensureAccess()) return false;
    try {
      await Gal.putImageBytes(bytes, album: _album);
      return true;
    } catch (e) {
      debugPrint('Lưu ảnh lỗi: $e');
      return false;
    }
  }

  static Future<bool> saveVideoFile(String path) async {
    if (!await ensureAccess()) return false;
    try {
      await Gal.putVideo(path, album: _album);
      return true;
    } catch (e) {
      debugPrint('Lưu video lỗi: $e');
      return false;
    }
  }
}
