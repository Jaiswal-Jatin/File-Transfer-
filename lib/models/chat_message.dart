class ChatMessage {
  final String id;
  final String deviceId;
  final String deviceName;
  final String message;
  final DateTime timestamp;
  final bool isFromMe;

  ChatMessage({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.message,
    required this.timestamp,
    required this.isFromMe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromMe: json['isFromMe'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isFromMe': isFromMe,
    };
  }
}
