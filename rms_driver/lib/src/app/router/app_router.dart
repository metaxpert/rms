import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../features/runs/presentation/run_list_screen.dart';
import '../../features/runs/presentation/run_screen.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const selectBranch = '/select-branch';
  static const home = '/';

  static String run(String deliveryId) => '/run/$deliveryId';
}

/// Router with the same authentication guard as the other apps: the redirect is
/// derived from [AuthState], so a token revoked server-side replaces whatever
/// screen the rider is on rather than failing on their next tap.
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
        builder: (context, state) => const SignInScreen(
          title: 'Driver sign in',
          icon: Icons.two_wheeler_rounded,
        ),
      ),
      GoRoute(
        path: Routes.selectBranch,
        builder: (context, state) =>
            const BranchSelectionScreen(title: 'Which kitchen?'),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const RunListScreen(),
        routes: [
          GoRoute(
            path: 'run/:deliveryId',
            builder: (context, state) => RunScreen(
              deliveryId: state.pathParameters['deliveryId']!,
            ),
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
        // Without an outlet every branch-scoped read falls back to unscoped
        // data — a rider would be shown another kitchen's runs.
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
