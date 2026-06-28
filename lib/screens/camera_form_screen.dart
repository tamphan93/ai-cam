import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera.dart';
import '../services/camera_store.dart';
import '../services/discovery_service.dart';
import '../services/onvif_service.dart';

/// Thêm mới hoặc chỉnh sửa một camera.
class CameraFormScreen extends StatefulWidget {
  const CameraFormScreen({super.key, this.existing});

  final Camera? existing;

  @override
  State<CameraFormScreen> createState() => _CameraFormScreenState();
}

class _CameraFormScreenState extends State<CameraFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _rtspPort;
  late final TextEditingController _onvifPort;

  bool _testing = false;
  bool _scanning = false;
  double _scanProgress = 0;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _host = TextEditingController(text: c?.host ?? '');
    _user = TextEditingController(text: c?.username ?? '');
    _pass = TextEditingController(text: c?.password ?? '');
    _rtspPort = TextEditingController(text: (c?.rtspPort ?? 554).toString());
    _onvifPort = TextEditingController(text: (c?.onvifPort ?? 2020).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _rtspPort.dispose();
    _onvifPort.dispose();
    super.dispose();
  }

  Camera _buildCamera() {
    final base = widget.existing;
    return Camera(
      id: base?.id ?? 'tmp',
      name: _name.text.trim(),
      host: _host.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      rtspPort: int.tryParse(_rtspPort.text) ?? 554,
      onvifPort: int.tryParse(_onvifPort.text) ?? 2020,
    );
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });
    final found = await DiscoveryService.scan(
      onProgress: (p) {
        if (mounted) setState(() => _scanProgress = p);
      },
    );
    if (!mounted) return;
    setState(() => _scanning = false);

    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không tìm thấy camera nào trong mạng'),
      ));
      return;
    }

    final picked = await showModalBottomSheet<DiscoveredCamera>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Camera tìm thấy',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final c in found)
              ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(c.host),
                subtitle: Text([
                  if (c.onvif) 'ONVIF:2020',
                  if (c.rtsp) 'RTSP:554',
                ].join('  ·  ')),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _host.text = picked.host);
    }
  }

  Future<void> _testOnvif() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final svc = OnvifService();
    final ok = await svc.connect(_buildCamera());
    svc.dispose();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Kết nối ONVIF thành công (PTZ sẵn sàng)'
          : 'Không kết nối được ONVIF — kiểm tra IP / cổng / tài khoản'),
    ));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = context.read<CameraStore>();
    final c = _buildCamera();
    if (widget.existing == null) {
      await store.add(
        name: c.name,
        host: c.host,
        username: c.username,
        password: c.password,
        rtspPort: c.rtspPort,
        onvifPort: c.onvifPort,
      );
    } else {
      await store.update(widget.existing!.copyWith(
        name: c.name,
        host: c.host,
        username: c.username,
        password: c.password,
        rtspPort: c.rtspPort,
        onvifPort: c.onvifPort,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Sửa camera' : 'Thêm camera')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _scanProgress == 0 ? null : _scanProgress,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_scanning
                  ? 'Đang quét... ${(_scanProgress * 100).round()}%'
                  : 'Quét tìm camera trong mạng'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên camera'),
              validator: _required,
            ),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ IP (vd 192.168.1.50)',
              ),
              keyboardType: TextInputType.url,
              validator: _required,
            ),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(
                labelText: 'Username (Camera Account trong app Tapo)',
              ),
              validator: _required,
            ),
            TextFormField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: _required,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rtspPort,
                    decoration: const InputDecoration(labelText: 'Cổng RTSP'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _onvifPort,
                    decoration: const InputDecoration(labelText: 'Cổng ONVIF'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testOnvif,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Kiểm tra kết nối ONVIF'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
