import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permissions for iOS/Android
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted permission');
    } else {
      developer.log('User declined or has not accepted permission');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Got a message whilst in the foreground!');
      developer.log('Message data: ${message.data}');

      if (message.notification != null) {
        developer.log(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });

    // Handle background/terminated state messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}

// Must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log("Handling a background message: ${message.messageId}");
}
