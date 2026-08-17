import 'delivery_alerts.dart';

/// Web, and anywhere else the plugin cannot run.
///
/// Silent rather than throwing: an alert the platform cannot deliver is not an
/// error a customer can do anything about, and the in-app banner still shows.
class _NoNotifications implements LocalNotifier {
  const _NoNotifications();

  @override
  Future<bool> prepare() async => false;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}

LocalNotifier createLocalNotifier() => const _NoNotifications();
