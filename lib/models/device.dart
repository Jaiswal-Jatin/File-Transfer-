class Device {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final bool isConnected;
  final DateTime lastSeen;

  const Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    this.isConnected = false,
    required this.lastSeen,
  });

  Device copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'isConnected': isConnected,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      ipAddress: json['ipAddress'],
      port: json['port'],
      isConnected: json['isConnected'] ?? false,
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }
}
