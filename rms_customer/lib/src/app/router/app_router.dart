import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rms_core/rms_core.dart';
import '../../l10n/app_text.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalogue/presentation/menu_screen.dart';
import '../../features/tracking/presentation/track_screen.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const selectBranch = '/choose-restaurant';
  static const home = '/';
  static const cart = '/cart';

  static String track(String orderId) => '/order/$orderId';
}

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
        builder: (context, state) => SignInScreen(
          title: appText(context).signInToOrder,
          icon: Icons.local_dining_rounded,
        ),
      ),
      GoRoute(
        path: Routes.selectBranch,
        builder: (context, state) =>
            BranchSelectionScreen(title: appText(context).chooseRestaurant),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const MenuScreen(),
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/order/:orderId',
        builder: (context, state) => TrackScreen(
          orderId: state.pathParameters['orderId']!,
          // Only present when the address could not be attached; see
          // CustomerOrderRepository.create.
          unsentAddress: state.extra as String?,
        ),
      ),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      return switch (status) {
        AuthStatus.signedOut =>
          location == Routes.signIn ? null : Routes.signIn,
        // A menu, its prices and its tax all belong to one restaurant; without
        // a choice every read would fall back to some other outlet's.
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
