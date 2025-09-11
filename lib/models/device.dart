// ignore_for_file: prefer_expression_function_bodies

import 'package:flutter/foundation.dart';

@immutable
class Device {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String platform;
  final DateTime lastSeen;
  final bool isConnected;

  const Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.platform,
    required this.lastSeen,
    this.isConnected = false,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['deviceId'] as String,
      name: json['deviceName'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      platform: json['platform'] as String,
      lastSeen: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}