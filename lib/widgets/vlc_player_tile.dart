import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import '../models/camera.dart';

/// Tùy chọn libVLC tối ưu cho RTSP độ trễ thấp.
VlcPlayerOptions lowLatencyOptions() => VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        VlcAdvancedOptions.networkCaching(150),
        VlcAdvancedOptions.clockJitter(0),
        VlcAdvancedOptions.clockSynchronization(0),
      ]),
      rtp: VlcRtpOptions([
        VlcRtpOptions.rtpOverRtsp(true), // RTSP over TCP -> ổn định hơn
      ]),
    );

/// Bọc một widget player, áp dụng xoay 180° nếu camera được cấu hình flip.
Widget applyFlip(Camera camera, Widget child) {
  if (!camera.flip180) return child;
  return Transform.rotate(angle: math.pi, child: child);
}

/// Ô xem live cho lưới nhiều cam (dùng stream SD cho nhẹ). Chạm để mở fullscreen.
/// Tự kết nối lại khi stream bị ngắt/lỗi.
class VlcPlayerTile extends StatefulWidget {
  const VlcPlayerTile({
    super.key,
    required this.camera,
    this.hd = false,
    this.onTap,
  });

  final Camera camera;
  final bool hd;
  final VoidCallback? onTap;

  @override
  State<VlcPlayerTile> createState() => _VlcPlayerTileState();
}

class _VlcPlayerTileState extends State<VlcPlayerTile> {
  late final VlcPlayerController _controller;
  Timer? _reconnectTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.camera.rtspUrl(hd: widget.hd),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: lowLatencyOptions(),
    );
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final state = _controller.value.playingState;
    if (state == PlayingState.error ||
        state == PlayingState.ended ||
        state == PlayingState.stopped) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      _reconnectTimer = null;
      if (_disposed) return;
      try {
        await _controller.setMediaFromNetwork(
          widget.camera.rtspUrl(hd: widget.hd),
          hwAcc: HwAcc.full,
          autoPlay: true,
        );
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _controller.removeListener(_onChanged);
    _controller.stopRendererScanning();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: applyFlip(
              widget.camera,
              VlcPlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
                placeholder: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.camera.name,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
