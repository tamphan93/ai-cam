import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera.dart';
import '../services/camera_store.dart';
import '../widgets/vlc_player_tile.dart';
import 'camera_form_screen.dart';
import 'gallery_screen.dart';
import 'live_view_screen.dart';
import 'settings_screen.dart';

/// Màn hình chính: lưới các camera (live SD), thêm/sửa/xóa, mở fullscreen.
class HomeGridScreen extends StatelessWidget {
  const HomeGridScreen({super.key});

  void _openLive(BuildContext context, Camera cam) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveViewScreen(camera: cam)),
    );
  }

  void _addOrEdit(BuildContext context, {Camera? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CameraFormScreen(existing: existing)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Camera cam) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xóa "${cam.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<CameraStore>().remove(cam.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CameraStore>();
    final cams = store.cameras;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapo C200'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GalleryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(context),
        child: const Icon(Icons.add),
      ),
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : cams.isEmpty
              ? _EmptyState(onAdd: () => _addOrEdit(context))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 16 / 9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cams.length,
                  itemBuilder: (context, i) {
                    final cam = cams[i];
                    return _GridCard(
                      // controller riêng cho mỗi cam (stream SD)
                      key: ValueKey('${cam.id}_sd'),
                      camera: cam,
                      onTap: () => _openLive(context, cam),
                      onEdit: () => _addOrEdit(context, existing: cam),
                      onDelete: () => _confirmDelete(context, cam),
                    );
                  },
                ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    super.key,
    required this.camera,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Camera camera;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VlcPlayerTile(camera: camera, hd: false, onTap: onTap),
          Positioned(
            right: 2,
            top: 2,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Chưa có camera nào'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Thêm camera'),
          ),
        ],
      ),
    );
  }
}
