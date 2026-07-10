import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

// Low-importance channel for the persistent "sharing location" foreground
// notification the Android foreground service requires.
const AndroidNotificationChannel trackingChannel = AndroidNotificationChannel(
  'bustrack_tracking',
  'Live Tracking',
  description: 'Shown while the driver is sharing live location',
  importance: Importance.low,
);

// High-importance alarm channel: wakes the screen with sound + vibration.
const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
  'bustrack_alarm',
  'Bus Proximity Alarm',
  description: 'Rings when your bus is approaching your stop',
  importance: Importance.max,
  playSound: true,
  // Drop alarm.mp3 in android/app/src/main/res/raw/ for a custom sound;
  // otherwise Android falls back to the default notification sound.
  sound: RawResourceAndroidNotificationSound('alarm'),
  enableVibration: true,
);

Future<void> initNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestSoundPermission: true,
    requestBadgePermission: true,
  );
  await flnp.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );
  final android = flnp.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(trackingChannel);
  await android?.createNotificationChannel(alarmChannel);
  await android?.requestNotificationsPermission();
}

/// Full-screen, alarm-style notification fired when the bus is near.
Future<void> showAlarmNotification(String title, String body) async {
  await flnp.show(
    9001,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'bustrack_alarm',
        'Bus Proximity Alarm',
        channelDescription: 'Rings when your bus is approaching your stop',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    ),
  );
}
