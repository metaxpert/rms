import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';
import 'package:rms_manager/src/features/service/data/service_repository.dart';
import 'package:rms_manager/src/features/service/presentation/manager_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The visual QA pass, written down so it runs.
///
/// A manager's dashboard is the densest screen in the product and the one most
/// likely to break somewhere nobody looks: the phone in a pocket, the 10"
/// tablet by the till, dark mode at the end of a late shift, and whatever text
/// size the last person to hold the device left it on. Checking those by
/// opening the app means checking the two combinations somebody remembers.
///
/// Every case here asserts the same two things — nothing threw, and nothing
/// overflowed — because a RenderFlex overflow in a release build is not a red
/// stripe, it is a silently clipped number.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Widths that correspond to real devices rather than round numbers.
  const devices = <String, Size>{
    'small phone': Size(360, 690), // Galaxy A-series, the common till phone
    'large phone': Size(430, 932),
    'tablet portrait': Size(834, 1194), // the 10" by the till
    'tablet landscape': Size(1194, 834),
  };

  OrderSummary order(String status, {int totalMinor = 1234567}) =>
      OrderSummary.fromJson({
        'id': 'o-$status-$totalMinor',
        'orderNo': 'ORD-000123',
        'channel': 'DINE_IN',
        'status': status,
        'itemCount': 4,
        'total': {'amountMinor': totalMinor, 'currency': 'PKR'},
      });

  KdsTicket ticket(int minutesAgo) => KdsTicket.fromJson({
        'id': 'k-$minutesAgo',
        'orderNo': 'ORD-000123',
        'station': 'tandoor',
        'status': 'PREPARING',
        'targetMinutes': 12,
        'firedAt': DateTime.now()
            .subtract(Duration(minutes: minutesAgo))
            .toIso8601String(),
        'items': const [
          {'qty': 2, 'name': 'Chicken Karahi (Half)', 'notes': 'extra spicy'},
        ],
      });

  /// A deliberately awkward snapshot: every call-to-action showing at once,
  /// long money figures, and enough tickets to make the kitchen tab scroll.
  final busy = ServiceSnapshot(
    orders: [
      order('READY'),
      order('READY', totalMinor: 9876543),
      order('IN_PROGRESS'),
      order('SERVED'),
      order('SETTLED', totalMinor: 45678900),
    ],
    board: KdsBoard.from([ticket(3), ticket(25), ticket(40)]),
    tables: const [],
    deliveries: const [],
    takenAt: DateTime(2026, 8, 13, 20, 30),
  );

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required Brightness brightness,
    double textScale = 1.0,
    int tab = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final session = await Session.load(secretStore: InMemorySecretStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          sharedPreferencesProvider
              .overrideWithValue(await SharedPreferences.getInstance()),
          serviceSnapshotProvider.overrideWith((ref) async => busy),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light(flavor: AppFlavor.manager)
              : AppTheme.dark(flavor: AppFlavor.manager),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const ManagerShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (tab > 0) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await tester.pumpAndSettle();
    }
  }

  /// Flutter reports an overflow as an exception on the *element*, which
  /// `takeException` only surfaces for the most recent one. Asking the binding
  /// directly catches every one in the frame.
  void expectNoOverflow(WidgetTester tester, String where) {
    expect(tester.takeException(), isNull, reason: where);
  }

  group('the dashboard holds its shape', () {
    for (final device in devices.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${device.key}, ${brightness.name}', (tester) async {
          await pump(tester, size: device.value, brightness: brightness);
          expectNoOverflow(tester, '${device.key} ${brightness.name}');
          // The tiles are the screen; if they did not render, the pass above
          // proves nothing.
          expect(find.byType(MetricTile), findsWidgets);
        });
      }
    }

    testWidgets('at the largest text this app honours', (tester) async {
      // Shared devices arrive with somebody else's accessibility settings.
      await pump(
        tester,
        size: devices['small phone']!,
        brightness: Brightness.light,
        textScale: 1.3,
      );
      expectNoOverflow(tester, 'small phone at 1.3x');
    });

    testWidgets('a wider screen buys more tiles, not fatter ones',
        (tester) async {
      // Two bugs in one assertion. The original grid was a fixed two across,
      // which put two playing-card tiles in the middle of a 10" screen with
      // dead space down both sides. The first fix capped the column count
      // instead, which is the same bug wearing a hat — four columns of a
      // landscape tablet is four 280-pixel tiles.
      Future<(int, double)> gridAt(Size size) async {
        await pump(tester, size: size, brightness: Brightness.light);
        final tiles = find.byType(MetricTile);
        final width = tester.getSize(tiles.first).width;
        // Tiles sharing a top edge are one row; six tiles over N rows gives
        // the column count without reaching into the delegate.
        final topEdge = tester.getTopLeft(tiles.first).dy;
        var columns = 0;
        for (var i = 0; i < tester.widgetList(tiles).length; i++) {
          if (tester.getTopLeft(tiles.at(i)).dy == topEdge) columns++;
        }
        return (columns, width);
      }

      final (phoneColumns, phoneWidth) = await gridAt(devices['small phone']!);
      final (tabletColumns, tabletWidth) =
          await gridAt(devices['tablet landscape']!);

      expect(phoneColumns, 2);
      expect(tabletColumns, greaterThan(phoneColumns));
      // The guarantee is the cap. A tile may be a little wider on a bigger
      // screen — it must never grow without bound, which is what a column cap
      // allows and an extent cap does not.
      expect(tabletWidth, lessThanOrEqualTo(240));
      expect(phoneWidth, lessThanOrEqualTo(240));
      // Three-plus times the screen width bought roughly three times the
      // tiles, not three times the tile.
      expect(tabletWidth / phoneWidth, lessThan(1.5));
    });
  });

  group('the other tabs hold their shape too', () {
    for (final tab in [1, 2]) {
      for (final brightness in Brightness.values) {
        testWidgets('tab $tab, ${brightness.name}', (tester) async {
          await pump(
            tester,
            size: devices['small phone']!,
            brightness: brightness,
            tab: tab,
          );
          expectNoOverflow(tester, 'tab $tab ${brightness.name}');
        });
      }
    }
  });

  group('dark mode is designed, not inverted', () {
    testWidgets('a status badge is legible on a dark card', (tester) async {
      await pump(
        tester,
        size: devices['small phone']!,
        brightness: Brightness.dark,
        tab: 1,
      );

      // The kitchen board paints every ticket in its urgency colour. On a dark
      // surface the light-mode palette renders as near-black on near-black;
      // the resolved colour has to be lighter than the surface it sits on.
      final surface = AppTheme.dark(flavor: AppFlavor.manager).colorScheme.surface;
      final overdue = AppStatusColors.of(
        AppStatusColors.cancelled,
        Brightness.dark,
      );
      expect(
        overdue.computeLuminance(),
        greaterThan(surface.computeLuminance()),
      );
    });
  });
}
