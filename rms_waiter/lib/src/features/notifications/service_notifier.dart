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

  /// Show an alert.
  ///
  /// Takes finished strings rather than the facts behind them, because this
  /// runs outside the widget tree and has no `BuildContext` to translate with.
  /// The caller has one; pushing the lookup there is what keeps the last of the
  /// app's copy out of a platform-channel wrapper.
  Future<void> foodReady({required String title, required String body});

  Future<void> orderSent({required String title, required String body});
}

final serviceNotifierProvider =
    Provider<ServiceNotifier>((ref) => createServiceNotifier());
