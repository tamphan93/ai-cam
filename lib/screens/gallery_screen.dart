import 'package:flutter/material.dart';

/// Màn hình thư viện (tối giản): ảnh/clip được lưu thẳng vào app Photos của
/// iPhone trong album "Tapo C200". Có thể mở rộng đọc trực tiếp bằng
/// package `photo_manager` nếu muốn xem trong app.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Ảnh chụp và clip quay được lưu trong app Photos của iPhone,\n'
                'trong album "Tapo C200".',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
