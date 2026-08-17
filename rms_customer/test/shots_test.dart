@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/cart/application/cart_controller.dart';
import 'package:rms_customer/src/features/cart/presentation/cart_screen.dart';
import 'package:rms_customer/src/features/catalogue/presentation/menu_screen.dart';
import 'package:rms_customer/src/features/orders/data/customer_order_repository.dart';
import 'package:rms_customer/src/features/tracking/presentation/track_screen.dart';
import 'package:rms_customer/src/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/shots.dart';

/// Renders the real guest-facing screens to PNG, headlessly, for design review.
///
/// Not an assertion suite: run with `--update-goldens` and look at the output.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  MenuCatalogue catalogue() => MenuCatalogue(
        config: RestaurantConfig.fromJson(const {
          'taxRateBp': 1600,
          'serviceChargeBp': 0,
          'currency': 'PKR',
        }),
        categories: [
          MenuCategory.fromJson(const {'id': 'c1', 'name': 'Karahi & Handi'}),
          MenuCategory.fromJson(const {'id': 'c2', 'name': 'Breads'}),
          MenuCategory.fromJson(const {'id': 'c3', 'name': 'Chai & Drinks'}),
        ],
        items: [
          MenuItem.fromJson(const {
            'id': 'i1',
            'categoryId': 'c1',
            'name': 'Chicken White Karahi (Half — serves two)',
            'effectivePrice': {'amountMinor': 189900, 'currency': 'PKR'},
            'prepMinutes': 25,
            'available': true,
          }),
          MenuItem.fromJson(const {
            'id': 'i2',
            'categoryId': 'c1',
            'name': 'Mutton Handi (Full)',
            'effectivePrice': {'amountMinor': 329900, 'currency': 'PKR'},
            'prepMinutes': 35,
            'available': true,
          }),
          MenuItem.fromJson(const {
            'id': 'i3',
            'categoryId': 'c2',
            'name': 'Roghni Naan',
            'effectivePrice': {'amountMinor': 8000, 'currency': 'PKR'},
            'available': true,
          }),
          // Sold out, because that is the state a menu spends its evening in.
          MenuItem.fromJson(const {
            'id': 'i4',
            'categoryId': 'c3',
            'name': 'Kashmiri Chai',
            'effectivePrice': {'amountMinor': 21050, 'currency': 'PKR'},
            'available': false,
          }),
        ],
      );

  final tracked = TrackedOrder(
    order: OrderDetail.fromJson({
      'id': 'order-1',
      'orderNo': 'ORD-000142',
      'status': 'IN_PROGRESS',
      'channel': 'DELIVERY',
      'guestCount': 0,
      'placedAt':
          DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      'totals': const {
        'subtotal': {'amountMinor': 227900, 'currency': 'PKR'},
        'tax': {'amountMinor': 36464, 'currency': 'PKR'},
        'total': {'amountMinor': 264364, 'currency': 'PKR'},
      },
      'items': const [
        {
          'id': 'l1',
          'name': 'Chicken White Karahi (Half — serves two)',
          'qty': 1,
          'unitPrice': {'amountMinor': 189900, 'currency': 'PKR'},
          'lineTotal': {'amountMinor': 189900, 'currency': 'PKR'},
        },
        {
          'id': 'l2',
          'name': 'Roghni Naan',
          'qty': 4,
          'unitPrice': {'amountMinor': 8000, 'currency': 'PKR'},
          'lineTotal': {'amountMinor': 32000, 'currency': 'PKR'},
        },
      ],
    }),
    delivery: Delivery.fromJson(const {
      'id': 'dlv-9',
      'deliveryNo': 'DLV-000031',
      'orderId': 'order-1',
      'orderNo': 'ORD-000142',
      'provider': 'OWN',
      'status': 'ASSIGNED',
      'address': 'House 212-B, Street 41, Sector F-11/3, Islamabad',
    }),
  );

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    required Widget home,
    bool fillCart = false,
    List<Override> extra = const [],
  }) async {
    enableShadowsForShot();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final session = await Session.load(secretStore: InMemorySecretStore());
    final menu = catalogue();

    // An explicit container, so the basket can be filled before anything is
    // built — writing from inside a builder is a write during a build.
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        menuCatalogueProvider.overrideWith((ref) async => menu),
        ...extra,
      ],
    );
    addTearDown(container.dispose);

    if (fillCart) {
      for (final item in menu.items.where((i) => i.available)) {
        container.read(cartControllerProvider.notifier).add(item, menu.config);
      }
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withRealFont(
            brightness == Brightness.light
                ? AppTheme.light(flavor: AppFlavor.customer)
                : AppTheme.dark(flavor: AppFlavor.customer),
          ),
          localizationsDelegates: const [
            RmsLocalizations.delegate,
            AppText.delegate,
          ],
          supportedLocales: AppText.supportedLocales,
          home: MediaQuery(data: MediaQueryData(size: size), child: home),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
    restoreShadowsAfterShot();
  }

  const phone = Size(390, 844);

  testWidgets('customer menu, light', (t) async {
    await shoot(t,
        name: 'customer-menu-light',
        size: phone,
        brightness: Brightness.light,
        home: const MenuScreen());
  });

  testWidgets('customer menu, dark', (t) async {
    await shoot(t,
        name: 'customer-menu-dark',
        size: phone,
        brightness: Brightness.dark,
        home: const MenuScreen());
  });

  testWidgets('customer cart, light', (t) async {
    await shoot(t,
        name: 'customer-cart-light',
        size: phone,
        brightness: Brightness.light,
        fillCart: true,
        home: const CartScreen());
  });

  testWidgets('customer tracking, light', (t) async {
    await shoot(t,
        name: 'customer-track-light',
        size: phone,
        brightness: Brightness.light,
        extra: [
          trackedOrderProvider('order-1').overrideWith((ref) async => tracked),
        ],
        home: const TrackScreen(orderId: 'order-1'));
  });

  testWidgets('customer tracking, dark', (t) async {
    await shoot(t,
        name: 'customer-track-dark',
        size: phone,
        brightness: Brightness.dark,
        extra: [
          trackedOrderProvider('order-1').overrideWith((ref) async => tracked),
        ],
        home: const TrackScreen(orderId: 'order-1'));
  });
}
