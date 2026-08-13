import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'service_notifier.dart';

/// Android and iOS.
class _DeviceNotifications implements ServiceNotifier {
  _DeviceNotifications();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// One channel, high importance, because everything this app raises is
  /// something a waiter is expected to act on within a minute. A "quiet"
  /// channel would be an alert nobody sees.
  static const _channel = AndroidNotificationChannel(
    'service',
    'Service alerts',
    description: 'Food ready at the pass, and orders that finally sent.',
    importance: Importance.high,
  );

  @override
  Future<bool> prepare() async {
    if (_ready) return true;

    final initialised = await _plugin.initialize(
      settings: const InitializationSettings(
        // The launcher icon, so no separate asset has to be kept in step with
        // the app's branding.
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
      // Android 13+ only; older versions grant it at install and return true.
      final granted = await android?.requestNotificationsPermission();
      _ready = granted ?? false;
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(alert: true, sound: true);
      _ready = granted ?? false;
    } else {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> foodReady({String? tableCode}) => _show(
        // A stable id per kind, so a second "food ready" replaces the first
        // rather than stacking a column of them down the shade.
        id: 1,
        title: tableCode == null ? 'Food is ready' : 'Table $tableCode — ready',
        body: 'Food is up at the pass.',
      );

  @override
  Future<void> orderSent({required String tableCode, String? orderNo}) => _show(
        id: 2,
        title: 'Order sent',
        body: orderNo == null || orderNo.isEmpty
            ? 'Table $tableCode reached the kitchen.'
            : 'Table $tableCode reached the kitchen · $orderNo',
      );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
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
          // A dining room is loud and a tablet is often in an apron; the buzz
          // is what gets noticed, not the sound.
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

ServiceNotifier createServiceNotifier() => _DeviceNotifications();
