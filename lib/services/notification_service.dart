import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/device.dart';

// A simple payload model for notifications to handle taps consistently.
class NotificationPayload {
  final String type;
  final String deviceJson; // A JSON string of the Device object

  NotificationPayload({required this.type, required this.deviceJson});

  String toJson() {
    return jsonEncode({
      'type': type,
      'deviceJson': deviceJson,
    });
  }

  factory NotificationPayload.fromJson(String jsonString) {
    final map = jsonDecode(jsonString);
    return NotificationPayload(
      type: map['type'] as String,
      deviceJson: map['deviceJson'] as String,
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Callback to handle notification taps when the app is running.
  // The main app widget will provide this function.
  final Function(Device device)? onNotificationTap;

  NotificationService({this.onNotificationTap});

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS and macOS
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      // onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _createNotificationChannels();
  }

  // This is for older iOS versions.
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    if (payload != null) {
      final notificationPayload = NotificationPayload.fromJson(payload);
      final device = Device.fromJson(jsonDecode(notificationPayload.deviceJson));
      onNotificationTap?.call(device);
    }
  }

  // This is for Android and newer iOS versions.
  void onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      final notificationPayload = NotificationPayload.fromJson(response.payload!);
      final device = Device.fromJson(jsonDecode(notificationPayload.deviceJson));
      onNotificationTap?.call(device);
    }
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel connectionChannel =
        AndroidNotificationChannel(
      'connections', // id
      'Connections', // title
      description: 'Notifications for device connections and disconnections.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
      'messages', // id
      'Messages', // title
      description: 'Notifications for new chat messages.',
      importance: Importance.max,
    );

    const AndroidNotificationChannel fileChannel = AndroidNotificationChannel(
      'files', // id
      'File Transfers', // title
      description: 'Notifications for file transfer status.',
      importance: Importance.max,
    );

    final plugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(connectionChannel);
    await plugin?.createNotificationChannel(messageChannel);
    await plugin?.createNotificationChannel(fileChannel);
  }

  Future<void> showDeviceConnectedNotification(Device device) async {
    final payload = NotificationPayload(
      type: 'connection',
      deviceJson: jsonEncode(device.toJson()),
    ).toJson();

    await _flutterLocalNotificationsPlugin.show(
      device.id.hashCode,
      'Device Connected',
      'Successfully connected to ${device.name}.',
      const NotificationDetails(
        android: AndroidNotificationDetails('connections', 'Connections'),
      ),
      payload: payload,
    );
  }

  Future<void> showMessageNotification(String senderName, String message, Device device) async {
    final payload = NotificationPayload(
      type: 'message',
      deviceJson: jsonEncode(device.toJson()),
    ).toJson();

    await _flutterLocalNotificationsPlugin.show(
      device.id.hashCode, // Use a consistent ID to replace old notifications from the same user
      senderName,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails('messages', 'Messages'),
      ),
      payload: payload,
    );
  }

  Future<void> showFileReceivedNotification(String fileName, Device sender) async {
    final payload = NotificationPayload(
      type: 'file_received',
      deviceJson: jsonEncode(sender.toJson()),
    ).toJson();

    await _flutterLocalNotificationsPlugin.show(
      fileName.hashCode,
      'File Received',
      '"$fileName" received from ${sender.name}.',
      const NotificationDetails(
        android: AndroidNotificationDetails('files', 'File Transfers'),
      ),
      payload: payload,
    );
  }

  Future<void> showFileSentNotification(String fileName, Device receiver) async {
    final payload = NotificationPayload(
      type: 'file_sent',
      deviceJson: jsonEncode(receiver.toJson()),
    ).toJson();

    await _flutterLocalNotificationsPlugin.show(
      (fileName + receiver.id).hashCode,
      'File Sent',
      '"$fileName" was sent successfully to ${receiver.name}.',
      const NotificationDetails(
        android: AndroidNotificationDetails('files', 'File Transfers'),
      ),
      payload: payload,
    );
  }
}