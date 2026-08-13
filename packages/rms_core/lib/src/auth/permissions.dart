import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth_controller.dart';

/// The restaurant permissions the backend defines.
///
/// Listed as constants so no screen writes one as a string literal and no
/// screen invents one that does not exist. These are the eight found in the
/// module; anything not here is not a permission this app may gate on.
abstract final class RestaurantPermissions {
  static const operate = 'restaurant:operate';
  static const orderWrite = 'restaurant:order:write';
  static const menuWrite = 'restaurant:menu:write';
  static const floorWrite = 'restaurant:floor:write';
  static const kdsOperate = 'restaurant:kds:operate';
  static const print = 'restaurant:print';
  static const configWrite = 'restaurant:config:write';
  static const deliveryDispatch = 'restaurant:delivery:dispatch';
}

/// What the signed-in user may do, as far as their token says.
///
/// **This is never the authorization boundary.** The server re-checks every
/// call, and a client that believed otherwise would be one stolen token away
/// from being the whole security model. What this is for is not offering a
/// waiter a button that will come back 403 — a dead end mid-service is worse
/// than an absent affordance.
///
/// The inverse mistake matters just as much: gating an action on a permission
/// whose name we are *guessing* would hide something a user is entitled to do.
/// So only permissions that were actually found in the module are used, and
/// where the mapping from an action to a permission is unverified the action is
/// left ungated and the server's answer is surfaced instead.
class Permissions {
  const Permissions(this._granted);

  final Set<String> _granted;

  /// A tenant admin carries `*`.
  ///
  /// A token with **no** permission claim allows everything, deliberately: a
  /// claim shape we did not expect must not lock a waiter out of their own job
  /// mid-service. The server still refuses anything they may not do, and that
  /// refusal is surfaced properly — whereas a locked-out waiter has no recourse
  /// but a manager and a reboot.
  bool has(String permission) {
    if (_granted.isEmpty) return true;
    return _granted.contains('*') || _granted.contains(permission);
  }

  /// May take and change orders — the waiter's core action.
  bool get canTakeOrders => has(RestaurantPermissions.orderWrite);

  /// May queue a slip to a printer.
  bool get canPrint => has(RestaurantPermissions.print);

  /// May work a service at all. Absent, the app is read-only.
  bool get canOperate =>
      has(RestaurantPermissions.operate) || canTakeOrders;

  /// True when the token carries no permission claim at all — see [has].
  bool get isUnknown => _granted.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is Permissions &&
      other._granted.length == _granted.length &&
      other._granted.containsAll(_granted);

  @override
  int get hashCode => Object.hashAllUnordered(_granted);
}

/// Permissions from the current access token.
///
/// Derived from the session rather than fetched: the claim travels in the JWT,
/// and asking the server what we already hold would be a round trip per screen.
///
/// Watches the auth state rather than the session, because [Session] is a
/// single mutable object — signing out and back in as a colleague with
/// different rights changes its contents without changing its identity, so
/// watching it directly would leave the previous user's permissions on screen.
final permissionsProvider = Provider<Permissions>((ref) {
  ref.watch(authControllerProvider);
  return Permissions(ref.read(sessionProvider).permissions);
});
