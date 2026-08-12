import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../features/service/presentation/manager_shell.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const home = '/';
}

/// Two routes, because a manager's app has one destination.
///
/// Note what is NOT here: an outlet gate. The other apps cannot function
/// without one — a floor or a rider's board is meaningless tenant-wide — but
/// comparing outlets is precisely a manager's job, so the outlet is a filter in
/// the app bar rather than a wall in front of it. That difference is declared
/// once, by overriding [authRequiresBranchProvider] in `main()`.
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
          title: 'Manager sign in',
          icon: Icons.insights_rounded,
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const ManagerShell(),
      ),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final signedOut = status == AuthStatus.signedOut;
      final atSignIn = state.matchedLocation == Routes.signIn;

      if (signedOut) return atSignIn ? null : Routes.signIn;
      return atSignIn ? Routes.home : null;
    },
  );
});
