/// Mô hình một camera Tapo C200 (hoặc cam tương thích RTSP/ONVIF).
///
/// Mật khẩu KHÔNG được serialize cùng metadata — nó được lưu riêng trong
/// Keychain qua [flutter_secure_storage]. Trường [password] chỉ là transient,
/// được nạp vào lúc runtime để dựng URL RTSP.
class Camera {
  Camera({
    required this.id,
    required this.name,
    required this.host,
    this.rtspPort = 554,
    this.onvifPort = 2020,
    required this.username,
    this.password = '',
  });

  final String id;
  String name;
  String host; // IP của camera trong LAN, ví dụ 192.168.1.50
  int rtspPort;
  int onvifPort;
  String username;

  /// Transient — không lưu vào prefs. Nạp từ secure storage khi dùng.
  String password;

  /// stream1 = 1080p (HD), stream2 = 360p (SD, nhẹ cho grid).
  String rtspUrl({bool hd = true}) {
    final stream = hd ? 'stream1' : 'stream2';
    final cred = Uri.encodeComponent(username) +
        ':' +
        Uri.encodeComponent(password);
    return 'rtsp://$cred@$host:$rtspPort/$stream';
  }

  /// Địa chỉ host:port dùng cho ONVIF.
  String get onvifHost => '$host:$onvifPort';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'rtspPort': rtspPort,
        'onvifPort': onvifPort,
        'username': username,
      };

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        rtspPort: (json['rtspPort'] as num?)?.toInt() ?? 554,
        onvifPort: (json['onvifPort'] as num?)?.toInt() ?? 2020,
        username: json['username'] as String,
      );

  Camera copyWith({
    String? name,
    String? host,
    int? rtspPort,
    int? onvifPort,
    String? username,
    String? password,
  }) =>
      Camera(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        rtspPort: rtspPort ?? this.rtspPort,
        onvifPort: onvifPort ?? this.onvifPort,
        username: username ?? this.username,
        password: password ?? this.password,
      );
}
