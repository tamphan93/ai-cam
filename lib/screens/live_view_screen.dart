import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:path_provider/path_provider.dart';

import '../models/camera.dart';
import '../services/media_saver.dart';
import '../services/onvif_service.dart';
import '../widgets/ptz_joystick.dart';
import '../widgets/vlc_player_tile.dart';

/// Xem 1 camera fullscreen: live HD/SD, mute, snapshot, record, PTZ + presets,
/// chế độ toàn màn hình ngang.
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
  bool _muted = true;
  bool _fullscreen = false;
  bool _volumeApplied = false;
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
    // Áp dụng âm lượng (mặc định mute) khi stream bắt đầu phát.
    if (!_volumeApplied && v.isPlaying) {
      _volumeApplied = true;
      _controller.setVolume(_muted ? 0 : 100);
    }
    if (!v.isRecording &&
        v.recordPath != null &&
        v.recordPath != _lastRecordPath) {
      _lastRecordPath = v.recordPath;
      _saveRecording(v.recordPath!);
    }
  }

  @override
  void dispose() {
    _restoreOrientation();
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
    _volumeApplied = false; // áp lại âm lượng cho media mới
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _controller.setVolume(_muted ? 0 : 100);
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _restoreOrientation();
    }
  }

  void _restoreOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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

  Future<void> _openPresets() async {
    final presets = await _onvif.getPresets();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add_location_alt),
              title: const Text('Lưu vị trí hiện tại thành preset'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _savePresetDialog();
              },
            ),
            const Divider(height: 1),
            if (presets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có preset nào'),
              )
            else
              for (final p in presets)
                ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(p.name),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _onvif.gotoPreset(p.token);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePresetDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tên preset'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'VD: Cửa chính'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ok = await _onvif.savePreset(name);
    _toast(ok ? 'Đã lưu preset "$name"' : 'Lưu preset thất bại');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) return _buildFullscreen();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.camera.name),
        actions: [
          IconButton(
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullscreen,
          ),
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
                if (_ptzReady)
                  _actionBtn(Icons.bookmarks, 'Preset', _openPresets),
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

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: VlcPlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          ),
          Positioned(
            top: 8,
            right: 56,
            child: IconButton(
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white),
              onPressed: _toggleMute,
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
