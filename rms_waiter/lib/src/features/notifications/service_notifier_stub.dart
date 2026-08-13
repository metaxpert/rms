import 'service_notifier.dart';

/// Web and anywhere else the plugin cannot run.
///
/// Silent rather than throwing: an alert the platform cannot deliver is not an
/// error the waiter can do anything about, and the in-app banner still fires.
class _NoNotifications implements ServiceNotifier {
  const _NoNotifications();

  @override
  Future<bool> prepare() async => false;

  @override
  Future<void> foodReady({required String title, required String body}) async {}

  @override
  Future<void> orderSent({required String title, required String body}) async {}
}

ServiceNotifier createServiceNotifier() => const _NoNotifications();
