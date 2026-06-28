import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Một camera tìm thấy khi quét mạng LAN.
class DiscoveredCamera {
  DiscoveredCamera({required this.host, required this.onvif, required this.rtsp});
  final String host;
  final bool onvif; // cổng 2020 mở
  final bool rtsp; // cổng 554 mở
}

/// Quét subnet /24 hiện tại để tìm camera (host mở cổng ONVIF 2020 hoặc RTSP 554).
///
/// Dùng TCP connect thay cho WS-Discovery multicast để tránh yêu cầu entitlement
/// multicast của iOS. Cần quyền Local Network (NSLocalNetworkUsageDescription).
class DiscoveryService {
  static const _onvifPort = 2020;
  static const _rtspPort = 554;
  static const _timeout = Duration(milliseconds: 350);
  static const _batch = 32; // số host quét song song mỗi đợt

  /// Trả về địa chỉ IPv4 cục bộ dạng "192.168.1.x" (loại loopback).
  static Future<String?> _localIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final ni in interfaces) {
        for (final addr in ni.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && ip.startsWith(RegExp(r'\d'))) {
            return ip;
          }
        }
      }
    } catch (e) {
      debugPrint('Lấy IP cục bộ lỗi: $e');
    }
    return null;
  }

  static Future<bool> _portOpen(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: _timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quét toàn bộ /24. [onProgress] báo tiến độ 0..1 (tùy chọn).
  static Future<List<DiscoveredCamera>> scan({
    void Function(double progress)? onProgress,
  }) async {
    final localIp = await _localIpv4();
    if (localIp == null) return [];

    final prefix = localIp.substring(0, localIp.lastIndexOf('.') + 1);
    final results = <DiscoveredCamera>[];

    for (var start = 1; start <= 254; start += _batch) {
      final end = (start + _batch - 1).clamp(1, 254);
      final futures = <Future<void>>[];
      for (var i = start; i <= end; i++) {
        final host = '$prefix$i';
        futures.add(() async {
          final onvif = await _portOpen(host, _onvifPort);
          final rtsp = await _portOpen(host, _rtspPort);
          if (onvif || rtsp) {
            results.add(DiscoveredCamera(host: host, onvif: onvif, rtsp: rtsp));
          }
        }());
      }
      await Future.wait(futures);
      onProgress?.call(end / 254);
    }

    results.sort((a, b) => a.host.compareTo(b.host));
    return results;
  }
}
