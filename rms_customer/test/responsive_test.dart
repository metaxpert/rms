import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_customer/src/features/cart/application/cart_controller.dart';
import 'package:rms_customer/src/features/cart/presentation/cart_screen.dart';
import 'package:rms_customer/src/features/catalogue/presentation/menu_screen.dart';
import 'package:rms_customer/src/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The visual QA pass for the one app a guest sees.
///
/// This app honours text scaling all the way to 2x — it runs on somebody's own
/// phone, with settings they chose for a reason, and unlike the staff tablets
/// there is nobody to ask. That ceiling is where layouts break, so it is where
/// they are checked. The dish tile in particular held its text in a fixed-height
/// box sized to the photo beside it, which at 2x clipped the price.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const devices = <String, Size>{
    'small phone': Size(360, 690),
    'large phone': Size(430, 932),
    'tablet landscape': Size(1194, 834),
  };

  MenuCatalogue catalogue() => MenuCatalogue(
        config: RestaurantConfig.fromJson(const {
          'taxRateBp': 1600,
          'serviceChargeBp': 0,
          'currency': 'PKR',
        }),
        categories: [
          MenuCategory.fromJson(const {'id': 'c1', 'name': 'Karahi & Handi'}),
          MenuCategory.fromJson(const {'id': 'c2', 'name': 'Breads'}),
        ],
        items: [
          // A long name with a qualifier, which is what real menus look like
          // and what a cramped tile truncates first.
          MenuItem.fromJson(const {
            'id': 'i1',
            'categoryId': 'c1',
            'name': 'Chicken White Karahi (Half — serves two)',
            // The branch-effective price, which is the key MenuItem reads.
            'effectivePrice': {'amountMinor': 189900, 'currency': 'PKR'},
            'prepMinutes': 25,
            'available': true,
          }),
          MenuItem.fromJson(const {
            'id': 'i2',
            'categoryId': 'c2',
            'name': 'Roghni Naan',
            'effectivePrice': {'amountMinor': 8000, 'currency': 'PKR'},
            'available': true,
          }),
        ],
      );

  Future<Widget> app(
    Widget home, {
    required Size size,
    required Brightness brightness,
    double textScale = 1.0,
    List<Override> overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = await Session.load(secretStore: InMemorySecretStore());

    return ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        menuCatalogueProvider.overrideWith((ref) async => catalogue()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light(flavor: AppFlavor.customer)
            : AppTheme.dark(flavor: AppFlavor.customer),
        localizationsDelegates: const [
          RmsLocalizations.delegate,
          AppText.delegate,
        ],
        supportedLocales: AppText.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: home,
        ),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    required Size size,
    required Brightness brightness,
    double textScale = 1.0,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await app(
      home,
      size: size,
      brightness: brightness,
      textScale: textScale,
      overrides: overrides,
    ));
    await tester.pumpAndSettle();
  }

  group('the menu holds its shape', () {
    for (final device in devices.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${device.key}, ${brightness.name}', (tester) async {
          await pump(
            tester,
            const MenuScreen(),
            size: device.value,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Roghni Naan'), findsOneWidget);
        });
      }
    }

    testWidgets('at the 2x text this app honours', (tester) async {
      for (final device in devices.values) {
        await pump(
          tester,
          const MenuScreen(),
          size: device,
          brightness: Brightness.light,
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull, reason: '$device at 2x');
      }
    });

    testWidgets('a tablet does not stretch a dish row across the whole screen',
        (tester) async {
      // The row is a photo on the left and a price on the right. Let it grow to
      // 1194 pixels and those two facts end up a hand's width apart.
      await pump(
        tester,
        const MenuScreen(),
        size: devices['tablet landscape']!,
        brightness: Brightness.light,
      );

      final tile = find.ancestor(
        of: find.text('Roghni Naan'),
        matching: find.byType(Card),
      );
      expect(tester.getSize(tile).width, lessThanOrEqualTo(720));
    });

    testWidgets('the price is never the thing that gets clipped',
        (tester) async {
      // It is what the guest is deciding on. Whatever else has to give, this
      // renders in full at every size and every text scale.
      for (final scale in [1.0, 1.5, 2.0]) {
        await pump(
          tester,
          const MenuScreen(),
          size: devices['small phone']!,
          brightness: Brightness.light,
          textScale: scale,
        );
        final price = find.text('Rs 1,899.00');
        expect(price, findsOneWidget, reason: 'at ${scale}x');
        expect(
          tester.widget<Text>(price).overflow,
          isNot(TextOverflow.ellipsis),
          reason: 'at ${scale}x',
        );
      }
    });
  });

  group('the basket holds its shape', () {
    /// The cart controller is easier to drive through its own API than to fake,
    /// so the basket is filled from the real catalogue on first build — the
    /// same call the menu screen makes when a guest taps a dish.
    Future<void> pumpCartWithItems(
      WidgetTester tester, {
      required Size size,
      required Brightness brightness,
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final session = await Session.load(secretStore: InMemorySecretStore());
      final menu = catalogue();

      // An explicit container, so the basket can be filled *before* anything is
      // built. Doing it from inside a builder is a write during a build, which
      // Riverpod refuses — correctly.
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          menuCatalogueProvider.overrideWith((ref) async => menu),
        ],
      );
      addTearDown(container.dispose);

      for (final item in menu.items) {
        container.read(cartControllerProvider.notifier).add(item, menu.config);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light(flavor: AppFlavor.customer)
                : AppTheme.dark(flavor: AppFlavor.customer),
            localizationsDelegates: const [
              RmsLocalizations.delegate,
              AppText.delegate,
            ],
            supportedLocales: AppText.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: const CartScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final device in devices.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${device.key}, ${brightness.name}', (tester) async {
          await pumpCartWithItems(
            tester,
            size: device.value,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a long dish name survives a small phone', (tester) async {
      // The bug this replaces: name, two 56dp steppers, a quantity and a total
      // shared one row, leaving about ninety pixels for the dish. The name now
      // has the width to itself.
      await pumpCartWithItems(
        tester,
        size: devices['small phone']!,
        brightness: Brightness.light,
      );

      final name = find.text('Chicken White Karahi (Half — serves two)');
      expect(name, findsOneWidget);

      // The name now sits on its own row, above the stepper, rather than
      // sharing one with two 48dp buttons and a total. Proven by geometry
      // rather than by width: a wrapping Text reports the width of its longest
      // line, so measuring it says nothing about the room it was given.
      final stepper = find.byIcon(Icons.add_rounded).first;
      expect(
        tester.getBottomLeft(name).dy,
        lessThanOrEqualTo(tester.getTopLeft(stepper).dy),
      );
    });

    testWidgets('and the 2x text a guest may have chosen', (tester) async {
      await pumpCartWithItems(
        tester,
        size: devices['small phone']!,
        brightness: Brightness.light,
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
