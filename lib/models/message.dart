enum MessageType {
  text,
  file,
  image,
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isFromMe;
  final MessageType type;
  final String? fileName;
  final int? fileSize;
  final String? filePath;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.isFromMe,
    this.type = MessageType.text,
    this.fileName,
    this.fileSize,
    this.filePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isFromMe': isFromMe,
      'type': type.name,
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromMe: false, // Incoming messages are not from me
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      filePath: json['filePath'],
    );
  }
}
