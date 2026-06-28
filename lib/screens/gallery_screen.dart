import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:photo_manager/photo_manager.dart';

/// Thư viện trong app: đọc ảnh/clip trong album "Tapo C200" của Photos.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const _albumName = 'Tapo C200';

  bool _loading = true;
  bool _denied = false;
  List<AssetEntity> _assets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    AssetPathEntity? album;
    for (final p in paths) {
      if (p.name == _albumName) {
        album = p;
        break;
      }
    }
    // Nếu chưa có album riêng (chưa chụp/quay), dùng "Recent"/tất cả.
    album ??= paths.isNotEmpty ? paths.first : null;

    final assets = album == null
        ? <AssetEntity>[]
        : await album.getAssetListPaged(page: 0, size: 200);

    if (!mounted) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  void _open(AssetEntity asset) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _AssetViewer(asset: asset)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
              ? _message(
                  'Chưa cấp quyền truy cập Photos.\n'
                  'Vào Cài đặt → app này → Ảnh để cấp quyền.')
              : _assets.isEmpty
                  ? _message('Chưa có ảnh/clip nào.')
                  : GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _assets.length,
                      itemBuilder: (context, i) =>
                          _Thumb(asset: _assets[i], onTap: () => _open(_assets[i])),
                    ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.asset, required this.onTap});
  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder(
            future: asset.thumbnailDataWithSize(const ThumbnailSize(220, 220)),
            builder: (context, snap) {
              if (snap.data == null) {
                return const ColoredBox(color: Colors.black12);
              }
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
          if (asset.type == AssetType.video)
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 22),
            ),
        ],
      ),
    );
  }
}

/// Xem 1 asset: ảnh (Image.file) hoặc video (libVLC từ file).
class _AssetViewer extends StatefulWidget {
  const _AssetViewer({required this.asset});
  final AssetEntity asset;

  @override
  State<_AssetViewer> createState() => _AssetViewerState();
}

class _AssetViewerState extends State<_AssetViewer> {
  File? _file;
  VlcPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final f = await widget.asset.file;
    if (!mounted || f == null) return;
    if (widget.asset.type == AssetType.video) {
      _video = VlcPlayerController.file(f, autoPlay: true);
    }
    setState(() => _file = f);
  }

  @override
  void dispose() {
    _video?.stopRendererScanning();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _file == null
            ? const CircularProgressIndicator()
            : widget.asset.type == AssetType.video && _video != null
                ? VlcPlayer(controller: _video!, aspectRatio: 16 / 9)
                : Image.file(_file!),
      ),
    );
  }
}
