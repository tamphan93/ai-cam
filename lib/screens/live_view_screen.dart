import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:path_provider/path_provider.dart';

import '../models/camera.dart';
import '../services/media_saver.dart';
import '../services/onvif_service.dart';
import '../widgets/ptz_joystick.dart';
import '../widgets/vlc_player_tile.dart';

/// Xem 1 camera fullscreen: live HD/SD, snapshot, record, PTZ.
class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({super.key, required this.camera});

  final Camera camera;

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  late final VlcPlayerController _controller;
  final _onvif = OnvifService();

  bool _hd = true;
  bool _recording = false;
  bool _ptzReady = false;
  String? _lastRecordPath;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.camera.rtspUrl(hd: _hd),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: lowLatencyOptions(),
    );
    _controller.addListener(_onPlayerChanged);
    _initPtz();
  }

  Future<void> _initPtz() async {
    final ok = await _onvif.connect(widget.camera);
    if (mounted) setState(() => _ptzReady = ok);
  }

  void _onPlayerChanged() {
    final v = _controller.value;
    if (!v.isRecording &&
        v.recordPath != null &&
        v.recordPath != _lastRecordPath) {
      _lastRecordPath = v.recordPath;
      _saveRecording(v.recordPath!);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerChanged);
    _controller.stopRendererScanning();
    _controller.dispose();
    _onvif.dispose();
    super.dispose();
  }

  Future<void> _toggleQuality() async {
    setState(() => _hd = !_hd);
    await _controller.setMediaFromNetwork(
      widget.camera.rtspUrl(hd: _hd),
      hwAcc: HwAcc.full,
      autoPlay: true,
    );
  }

  Future<void> _snapshot() async {
    try {
      final bytes = await _controller.takeSnapshot();
      final ok = await MediaSaver.saveImageBytes(bytes);
      _toast(ok ? 'Đã lưu ảnh vào Photos' : 'Lưu ảnh thất bại');
    } catch (e) {
      _toast('Chụp ảnh lỗi: $e');
    }
  }

  Future<void> _toggleRecord() async {
    try {
      if (!_recording) {
        final dir = await getTemporaryDirectory();
        await _controller.startRecording(dir.path);
        setState(() => _recording = true);
        _toast('Bắt đầu quay');
      } else {
        await _controller.stopRecording();
        setState(() => _recording = false);
        _toast('Đang lưu clip...');
      }
    } catch (e) {
      _toast('Quay clip lỗi: $e');
    }
  }

  Future<void> _saveRecording(String path) async {
    final ok = await MediaSaver.saveVideoFile(path);
    _toast(ok ? 'Đã lưu clip vào Photos' : 'Lưu clip thất bại');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.camera.name),
        actions: [
          TextButton(
            onPressed: _toggleQuality,
            child: Text(
              _hd ? 'HD' : 'SD',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: VlcPlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(Icons.camera_alt, 'Chụp', _snapshot),
                _actionBtn(
                  _recording ? Icons.stop_circle : Icons.fiber_manual_record,
                  _recording ? 'Dừng' : 'Quay',
                  _toggleRecord,
                  color: _recording ? Colors.red : Colors.white,
                ),
              ],
            ),
          ),
          if (_ptzReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PtzJoystick(
                onMove: _onvif.move,
                onStop: _onvif.stop,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'PTZ không khả dụng (kiểm tra ONVIF / tài khoản cam)',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 36,
          color: color,
          onPressed: onTap,
          icon: Icon(icon),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
