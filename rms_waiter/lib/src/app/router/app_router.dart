import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/authentication/presentation/sign_in_screen.dart';
import '../../features/bill/presentation/bill_screen.dart';
import '../../features/branches/presentation/branch_selection_screen.dart';
import '../../features/floor/presentation/floor_screen.dart';
import '../../features/ticket/presentation/ticket_screen.dart';

/// Route names, so no screen navigates with a magic string (brief §33).
abstract final class Routes {
  static const signIn = '/sign-in';
  static const selectBranch = '/select-branch';
  static const home = '/';

  /// A table's ticket. The table object travels as `extra` to save a lookup,
  /// but the id is in the path so the route still works without it.
  static String ticket(String tableId) => '/table/$tableId';

  /// The bill for a table. Nested under the ticket so backing out of a
  /// settlement returns to the order rather than the floor.
  static String bill(String tableId) => '/table/$tableId/bill';
}

/// Router with an authentication guard (brief §38).
///
/// The redirect is derived from [AuthState] rather than each screen pushing and
/// popping: when a token is revoked server-side the controller flips to
/// `signedOut` and every open screen is replaced on the next frame, wherever the
/// waiter happens to be.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier(ref.read(authControllerProvider).status);
  ref.listen(authControllerProvider, (previous, next) {
    notifier.value = next.status;
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: notifier,
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.selectBranch,
        builder: (context, state) => const BranchSelectionScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const FloorScreen(),
        routes: [
          GoRoute(
            path: 'table/:tableId',
            builder: (context, state) => TicketScreen(
              tableId: state.pathParameters['tableId']!,
              table: state.extra as RestaurantTable?,
            ),
            routes: [
              GoRoute(
                path: 'bill',
                builder: (context, state) => BillScreen(
                  tableId: state.pathParameters['tableId']!,
                  // Only for the title; the bill itself is fetched by table id.
                  tableCode: state.extra as String?,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      return switch (status) {
        AuthStatus.signedOut =>
          location == Routes.signIn ? null : Routes.signIn,
        // Authenticated but no outlet chosen. Letting them through would show
        // another outlet's tables, since every branch-scoped read would fall
        // back to unscoped data.
        AuthStatus.needsBranch =>
          location == Routes.selectBranch ? null : Routes.selectBranch,
        AuthStatus.ready =>
          (location == Routes.signIn || location == Routes.selectBranch)
              ? Routes.home
              : null,
      };
    },
  );
});
