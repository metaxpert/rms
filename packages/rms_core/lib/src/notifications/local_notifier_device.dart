import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'delivery_alerts.dart';

/// Android and iOS.
class _DeviceNotifications implements LocalNotifier {
  _DeviceNotifications();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// One channel, high importance. Everything raised here is a change of state in
  /// somebody's dinner — "your rider is at the gate" is not a quiet notification,
  /// and a low-importance channel is an alert nobody sees.
  static const _channel = AndroidNotificationChannel(
    'delivery',
    'Delivery updates',
    description: 'Where your order is, and when the rider is close.',
    importance: Importance.high,
  );

  @override
  Future<bool> prepare() async {
    if (_ready) return true;
    // Nothing about an alert is worth taking the app down for. A missing platform
    // channel, an OEM Android that refuses the call, a headless test — all of them
    // end with "no notifications", never with a customer staring at a red screen
    // instead of their order.
    try {
      return _ready = await _initialise();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _initialise() async {
    final initialised = await _plugin.initialize(
      settings: const InitializationSettings(
        // The launcher icon, so no separate asset has to be kept in step with the
        // app's branding.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly below instead, so a refusal can be reported
          // rather than swallowed at startup.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (initialised != true) return false;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      // Android 13+ only; older versions grant at install and return true.
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await prepare()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            // A phone in a pocket while somebody waits for dinner: the buzz is
            // what gets noticed, not the sound.
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // As above: an alert that cannot be shown is not worth an exception on a
      // screen somebody is watching their dinner on.
    }
  }
}

LocalNotifier createLocalNotifier() => _DeviceNotifications();
