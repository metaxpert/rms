@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rms_core/rms_core.dart';

import 'support/shots.dart';

/// One page of the shared design system, rendered to PNG for review.
///
/// The four apps import these widgets rather than each drawing their own; this
/// is the sheet that shows what they are getting. Not an assertion suite — the
/// guarantees are in `design_system_test.dart`. Run with `--update-goldens`.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    const statuses = <String, Color>{
      'Free': AppStatusColors.available,
      'Seated': AppStatusColors.seated,
      'Ordering': AppStatusColors.ordering,
      'Cooking': AppStatusColors.preparing,
      'Ready': AppStatusColors.ready,
      'Served': AppStatusColors.served,
      'Bill asked': AppStatusColors.billRequested,
      'Settled': AppStatusColors.settled,
      'Cancelled': AppStatusColors.cancelled,
      'Reserved': AppStatusColors.reserved,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system'),
        // The one thing that differs per app: the primary hue.
        actions: [Chip(label: Text(flavor.name))],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          const SectionHeader('STATUS BADGES'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in statuses.entries)
                  StatusBadge(label: s.key, color: s.value),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('METRIC TILES'),
          // A tile spaces its label and value apart, so it needs a height to
          // do it in. On the dashboard the grid supplies one.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 132,
              child: Row(
              children: [
                const Expanded(
                  child: MetricTile(
                    label: 'Open bills',
                    value: '4',
                    icon: Icons.receipt_long_rounded,
                    detail: 'Rs 135,802.44',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricTile(
                    label: 'Ready to serve',
                    value: '2',
                    icon: Icons.room_service_rounded,
                    detail: 'go now',
                    highlight: true,
                    onTap: () {},
                  ),
                ),
              ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('NOTICES'),
          const AppNotice(
            title: '2 orders are ready to run',
            message: 'Food is up and waiting at the pass.',
            icon: Icons.room_service_rounded,
            accent: AppStatusColors.ready,
          ),
          const AppNotice(
            title: 'These figures are 11 minutes old',
            message: 'The connection dropped; pull to refresh.',
            icon: Icons.cloud_off_rounded,
            tone: NoticeTone.warning,
          ),
          const AppNotice(
            title: 'That did not reach the kitchen',
            message: 'Nothing was charged. Send it again.',
            icon: Icons.error_outline_rounded,
            tone: NoticeTone.danger,
          ),
          const AppNotice(
            title: 'Bill settled',
            message: 'Table D4 is free to clean.',
            icon: Icons.check_circle_outline_rounded,
            tone: NoticeTone.success,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('SEARCH'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchField(
              controller: TextEditingController(text: 'karahi'),
              hintText: 'Search the menu',
              clearTooltip: 'Clear',
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('BUTTONS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Send order')),
                OutlinedButton(onPressed: () {}, child: const Text('Add item')),
                TextButton(onPressed: () {}, child: const Text('Cancel')),
                const FilledButton(onPressed: null, child: Text('Disabled')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('LOADING — SKELETONS, NOT SPINNERS'),
          const SizedBox(
            height: 210,
            child: SkeletonGroup(child: SkeletonList(rows: 3)),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Brightness brightness,
    AppFlavor flavor = AppFlavor.manager,
    required Widget home,
  }) async {
    enableShadowsForShot();
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: withRealFont(
          brightness == Brightness.light
              ? AppTheme.light(flavor: flavor)
              : AppTheme.dark(flavor: flavor),
        ),
        localizationsDelegates: const [RmsLocalizations.delegate],
        supportedLocales: RmsLocalizations.supportedLocales,
        home: MediaQuery(data: MediaQueryData(size: size), child: home),
      ),
    );
    // Skeletons shimmer forever, so the tree never settles; pump a fixed
    // number of frames to land mid-animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
    restoreShadowsAfterShot();
  }

  const phone = Size(390, 1500);

  testWidgets('design system, light', (t) async {
    await shoot(t,
        name: 'core-design-system-light',
        size: phone,
        brightness: Brightness.light,
        home: const _Gallery(flavor: AppFlavor.manager));
  });

  testWidgets('design system, dark', (t) async {
    await shoot(t,
        name: 'core-design-system-dark',
        size: phone,
        brightness: Brightness.dark,
        home: const _Gallery(flavor: AppFlavor.manager));
  });

  testWidgets('empty state', (t) async {
    await shoot(t,
        name: 'core-empty-light',
        size: const Size(390, 500),
        brightness: Brightness.light,
        home: Scaffold(
          body: EmptyView(
            icon: Icons.table_restaurant_rounded,
            title: 'No tables set up yet',
            message: 'Add a dining area in the console and it will show here.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('Open the console'),
            ),
          ),
        ));
  });

  // The two screens every user of every app meets first, and the only two the
  // guest-facing and staff-facing halves of the product genuinely share.
  testWidgets('splash', (t) async {
    await shoot(t,
        name: 'core-splash-light',
        size: const Size(390, 844),
        brightness: Brightness.light,
        flavor: AppFlavor.customer,
        home: const SplashScreen(
          flavor: AppFlavor.customer,
          title: 'RMS Guest',
        ));
  });

  for (final (label, size, brightness) in [
    ('core-sign-in-light', const Size(390, 900), Brightness.light),
    ('core-sign-in-dark', const Size(390, 900), Brightness.dark),
    // The landscape split, which is what a till and a manager's tablet
    // actually run at.
    ('core-sign-in-tablet-light', const Size(1194, 834), Brightness.light),
  ]) {
    testWidgets('sign in — $label', (t) async {
      // Session.load goes to SharedPreferences, which without mock values sits
      // on a platform channel that never answers under flutter_test.
      SharedPreferences.setMockInitialValues(const {});
      final session = await Session.load(secretStore: InMemorySecretStore());

      await shoot(t,
          name: label,
          size: size,
          brightness: brightness,
          flavor: AppFlavor.waiter,
          home: ProviderScope(
            overrides: [sessionProvider.overrideWithValue(session)],
            child: const SignInScreen(title: 'Waiter sign in'),
          ));
    });
  }

  testWidgets('error state', (t) async {
    await shoot(t,
        name: 'core-error-light',
        size: const Size(390, 500),
        brightness: Brightness.light,
        home: Scaffold(
          body: ErrorView(
            error: ApiException(
              ApiErrorKind.network,
              'The kitchen display is not answering.',
              status: 503,
              traceId: '9f2c-4a10-bb31',
            ),
            onRetry: () {},
          ),
        ));
  });
}
