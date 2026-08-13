import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_notifier_stub.dart'
    if (dart.library.io) 'service_notifier_device.dart';

/// Getting a waiter's attention when they are not looking at the app.
///
/// An interface with a conditional implementation, for two reasons. The
/// notification plugin has no web implementation and imports `dart:io`, so a
/// direct dependency would break `flutter build web`. And it makes the alerting
/// rules testable without a platform channel.
///
/// **This is a local notification, not a push.** It only fires while the app's
/// process is alive — a tablet in an apron pocket with the screen off, whose
/// socket is still connected. Waking a killed app needs a push service and a
/// device-token endpoint to register with, and no such endpoint exists in the
/// backend. Saying that plainly is better than shipping something that appears
/// to be push and silently is not.
abstract class ServiceNotifier {
  /// Prepare the channel and ask for permission if the platform wants one.
  /// Returns false when notifications will not be delivered, so the app can
  /// stop pretending they will.
  Future<bool> prepare();

  /// Food is up for a table.
  Future<void> foodReady({String? tableCode});

  /// A submission the network had interrupted has now reached the kitchen.
  Future<void> orderSent({required String tableCode, String? orderNo});
}

final serviceNotifierProvider =
    Provider<ServiceNotifier>((ref) => createServiceNotifier());
