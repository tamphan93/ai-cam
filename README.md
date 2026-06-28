# Tapo C200 Viewer (Flutter / iOS)

Ứng dụng iPhone xem camera **Tapo C200** trực tiếp qua **RTSP** (độ trễ thấp bằng libVLC) và điều khiển **PTZ** qua **ONVIF** — chạy gọn trên iPhone, **không cần server riêng**.

## Tính năng
- 🎥 Live view độ trễ thấp (libVLC, RTSP over TCP, network-caching thấp)
- 🔲 Lưới nhiều camera (dùng stream SD cho nhẹ), chạm để mở fullscreen HD
- 📸 Chụp ảnh (snapshot) → lưu vào Photos
- ⏺️ Quay clip (record) → lưu vào Photos
- 🕹️ Điều khiển PTZ (xoay/nghiêng) qua ONVIF
- 🔀 Đổi HD / SD khi xem fullscreen
- 🔍 Quét mạng LAN tự tìm camera (cổng ONVIF/RTSP)
- 🖼️ Thư viện trong app: xem lại ảnh/clip đã lưu
- 🔐 Mật khẩu camera lưu trong Keychain (flutter_secure_storage)

## Yêu cầu phía camera (làm 1 lần trong app Tapo)
1. Mở app **Tapo** → chọn C200 → **Advanced Settings → Camera Account**.
2. Tạo **username / password** (đây KHÁC tài khoản TP-Link, dùng cho RTSP/ONVIF).
3. Ghi lại **IP** của camera (xem trong app Tapo hoặc router).
4. iPhone và camera phải **cùng mạng Wi-Fi**.

URL stream của C200: `rtsp://USER:PASS@IP:554/stream1` (1080p) và `/stream2` (360p).
ONVIF: cổng `2020`.

## Cấu trúc code
```
lib/
  main.dart
  models/camera.dart
  services/
    camera_store.dart   # CRUD cam + Keychain
    onvif_service.dart  # kết nối ONVIF + PTZ
    media_saver.dart    # lưu ảnh/clip vào Photos
  widgets/
    vlc_player_tile.dart # ô live + lowLatencyOptions()
    ptz_joystick.dart    # D-pad PTZ
  screens/
    home_grid_screen.dart
    live_view_screen.dart
    camera_form_screen.dart
    gallery_screen.dart
```

## Build trên máy Mac (bắt buộc dùng macOS + Xcode)

> Repo này chỉ chứa `lib/` + `pubspec.yaml`. Phần native (`ios/`, `android/`) được Flutter sinh ra ở máy bạn.

```bash
# 1. Tại thư mục dự án, sinh phần native cho iOS (và Android nếu muốn)
flutter create . --platforms=ios,android --project-name tapo_c200_viewer

# 2. Cài dependencies
flutter pub get

# 3. Cài CocoaPods cho iOS
cd ios && pod install && cd ..
```

### Cấu hình iOS bắt buộc — `ios/Runner/Info.plist`
Thêm các khóa sau vào `<dict>` (rất quan trọng, thiếu sẽ không kết nối được cam):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>App cần truy cập mạng nội bộ để kết nối camera Tapo.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>App cần quyền lưu ảnh chụp và clip vào Thư viện ảnh.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>App cần quyền đọc Thư viện ảnh để hiển thị lại ảnh/clip đã lưu.</string>

<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

> `NSAllowsArbitraryLoads` cần cho RTSP/ONVIF qua HTTP nội bộ. `NSLocalNetworkUsageDescription` là bắt buộc trên iOS 14+ để truy cập thiết bị trong LAN.

### Podfile
`flutter_vlc_player` cần iOS tối thiểu 12. Trong `ios/Podfile`, đảm bảo:
```ruby
platform :ios, '12.0'
```

### Chạy lên iPhone thật
```bash
flutter run --release
```
> ⚠️ libVLC/RTSP **không chạy tốt trên iOS Simulator** — hãy dùng **iPhone thật** cùng Wi-Fi với camera. Cần mở Xcode để ký (signing) bằng Apple ID của bạn lần đầu.

## Lưu ý kỹ thuật

### PTZ / ONVIF (version-sensitive)
API của gói `easy_onvif` thay đổi theo version. Code dùng:
```dart
onvif.ptz.continuousMove(token, velocity: PtzPosition(panTilt: Vector2D(x, y)));
onvif.ptz.stop(token);
```
Nếu `flutter pub get` kéo về version có chữ ký khác và báo lỗi compile ở `lib/services/onvif_service.dart`, đối chiếu với tài liệu version bạn cài tại https://pub.dev/packages/easy_onvif và chỉnh lại lời gọi `continuousMove` / `stop` cho khớp (đây là điểm duy nhất phụ thuộc version).

### Độ trễ
Đã tinh chỉnh `network-caching=150ms`, `clock-jitter=0`, `clock-synchro=0`, RTSP-over-TCP để giảm độ trễ (~1s). Nếu hình giật, tăng `network-caching` trong `lib/widgets/vlc_player_tile.dart`.

### Hiệu năng grid
Lưới dùng `stream2` (360p) để giảm tải khi xem nhiều cam cùng lúc; fullscreen dùng `stream1` (1080p).

### Quét tìm camera (discovery)
Trong màn hình thêm camera có nút **"Quét tìm camera trong mạng"**: app quét subnet /24
hiện tại bằng TCP connect tới cổng ONVIF (2020) và RTSP (554) — không dùng WS-Discovery
multicast để tránh phải xin entitlement multicast của iOS. Cần đã cấp quyền Local Network.
Sau khi quét, chạm IP để điền sẵn, rồi nhập username/password (Camera Account).

## Roadmap (chưa làm)
- Hỗ trợ Android (code đã sẵn sàng, cần test + quyền tương ứng)
- Đa subnet / nhập dải IP tùy chỉnh khi quét
