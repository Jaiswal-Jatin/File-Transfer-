import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    if (defaultTargetPlatform == TargetPlatform.iOS || 
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to transfers screen
  }

  static Future<void> showIncomingTransfer(
    String fileName, 
    String deviceName, 
    String transferId,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'incoming_transfers',
      'Incoming File Transfers',
      channelDescription: 'Notifications for incoming file transfer requests',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      transferId.hashCode,
      'Incoming File Transfer',
      '$deviceName wants to send "$fileName"',
      details,
      payload: transferId,
    );
  }

  static Future<void> showTransferComplete(
    String fileName, 
    bool wasSending,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'transfer_complete',
      'Transfer Complete',
      channelDescription: 'Notifications for completed file transfers',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final title = wasSending ? 'File Sent' : 'File Received';
    final body = wasSending 
        ? 'Successfully sent "$fileName"'
        : 'Successfully received "$fileName"';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static Future<void> showTransferProgress(
    String fileName,
    double progress,
    String transferId,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'transfer_progress',
      'Transfer Progress',
      channelDescription: 'Progress notifications for file transfers',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = AndroidNotificationDetails(
      'transfer_progress',
      'Transfer Progress',
      channelDescription: 'Progress notifications for file transfers',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).round(),
    );

    await _notifications.show(
      transferId.hashCode,
      'Transferring File',
      '$fileName - ${(progress * 100).toStringAsFixed(0)}%',
      NotificationDetails(android: details, iOS: iosDetails),
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
