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

/// Ô xem live cho lưới nhiều cam (dùng stream SD cho nhẹ). Chạm để mở fullscreen.
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

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.camera.rtspUrl(hd: widget.hd),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: lowLatencyOptions(),
    );
  }

  @override
  void dispose() {
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
            child: VlcPlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
              placeholder: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
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
