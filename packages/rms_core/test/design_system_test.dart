import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// The design system's own guarantees.
///
/// These are the properties that four apps are relying on and that nothing else
/// checks. The screen tests each hold one screen to WCAG AA in light mode; none
/// of them opens in dark mode, and none of them covers a status the screen it
/// tests happens not to show. That gap is exactly where the bug this file was
/// written for lived: the status palette is defined for a light surface, and
/// every badge in the product rendered it unchanged on a dark one.
void main() {
  /// WCAG's contrast ratio between two opaque colours.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Every semantic status, by the name a reader would use for it.
  const statuses = <String, Color>{
    'available': AppStatusColors.available,
    'seated': AppStatusColors.seated,
    'ordering': AppStatusColors.ordering,
    'preparing': AppStatusColors.preparing,
    'ready': AppStatusColors.ready,
    'served': AppStatusColors.served,
    'billRequested': AppStatusColors.billRequested,
    'settled': AppStatusColors.settled,
    'cancelled': AppStatusColors.cancelled,
    'reserved': AppStatusColors.reserved,
  };

  group('status colours survive both brightnesses', () {
    test('a badge label clears WCAG AA on the surface it is drawn on', () {
      // The badge fills with the status at 14% over the card surface and then
      // writes the label on top, so the label's real background is the blend —
      // not the surface, and not the status colour.
      for (final brightness in Brightness.values) {
        final scheme = AppTheme.light().colorScheme;
        final surface = brightness == Brightness.light
            ? scheme.surface
            : AppTheme.dark().colorScheme.surface;

        for (final entry in statuses.entries) {
          final fill = AppStatusColors.of(entry.value, brightness);
          final ink = AppStatusColors.textOn(entry.value, brightness);
          final background =
              Color.alphaBlend(fill.withValues(alpha: 0.14), surface);

          expect(
            contrast(ink, background),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on $brightness is unreadable at badge size',
          );
        }
      }
    });

    test('the dark correction lifts rather than darkens', () {
      // The original table darkened every status to reach AA on white. Applied
      // on a dark surface that is precisely backwards, and it is silent: the
      // badge still renders, just illegibly.
      for (final entry in statuses.entries) {
        final light = AppStatusColors.textOn(entry.value, Brightness.light);
        final dark = AppStatusColors.textOn(entry.value, Brightness.dark);

        expect(
          dark.computeLuminance(),
          greaterThan(light.computeLuminance()),
          reason: '${entry.key} must get lighter in dark mode, not darker',
        );
      }
    });

    test('a status keeps its identity across brightnesses', () {
      // Same meaning, same hue. A waiter who has learned that cyan means "food
      // up" must not have to re-learn it when the tablet flips at dusk.
      for (final entry in statuses.entries) {
        final light = HSLColor.fromColor(entry.value);
        final dark = HSLColor.fromColor(
          AppStatusColors.of(entry.value, Brightness.dark),
        );

        // Greys carry no hue to preserve; everything else stays within a
        // neighbouring shade.
        if (light.saturation < 0.1) continue;
        final drift = (light.hue - dark.hue).abs();
        expect(
          drift < 20 || drift > 340,
          isTrue,
          reason: '${entry.key} changed hue between brightnesses',
        );
      }
    });

    test('every status is distinguishable from every other', () {
      // Colour is never the only signal — badges always carry a word and an
      // icon — but two statuses that render identically make the colour
      // actively misleading rather than merely redundant.
      for (final brightness in Brightness.values) {
        final seen = <int, String>{};
        for (final entry in statuses.entries) {
          final resolved = AppStatusColors.of(entry.value, brightness).toARGB32();
          expect(
            seen[resolved],
            isNull,
            reason: '${entry.key} and ${seen[resolved]} collide on $brightness',
          );
          seen[resolved] = entry.key;
        }
      }
    });
  });

  group('the type scale', () {
    test('defines every style a screen is allowed to reach for', () {
      final text = AppTheme.light().textTheme;
      final styles = {
        'displaySmall': text.displaySmall,
        'headlineLarge': text.headlineLarge,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };

      for (final entry in styles.entries) {
        expect(entry.value?.fontSize, isNotNull, reason: entry.key);
        expect(entry.value?.height, isNotNull, reason: entry.key);
      }
    });

    test('nothing is smaller than 11, and nothing load-bearing is that small', () {
      final text = AppTheme.light().textTheme;
      // Below 11 is unreadable at arm's length in a dim dining room, and the
      // contrast suite's "large text" relaxation runs the other way: shrinking
      // a style is a contrast regression waiting to be found by a person.
      expect(text.labelSmall!.fontSize, greaterThanOrEqualTo(11));
      expect(text.bodySmall!.fontSize, greaterThanOrEqualTo(12));
      expect(text.bodyMedium!.fontSize, greaterThanOrEqualTo(14));
    });

    test('sizes descend monotonically through each family', () {
      final text = AppTheme.light().textTheme;
      expect(text.headlineLarge!.fontSize, greaterThan(text.headlineMedium!.fontSize!));
      expect(text.headlineMedium!.fontSize, greaterThan(text.headlineSmall!.fontSize!));
      expect(text.titleLarge!.fontSize, greaterThan(text.titleMedium!.fontSize!));
      expect(text.titleMedium!.fontSize, greaterThan(text.titleSmall!.fontSize!));
      expect(text.bodyLarge!.fontSize, greaterThan(text.bodyMedium!.fontSize!));
      expect(text.bodyMedium!.fontSize, greaterThan(text.bodySmall!.fontSize!));
    });

    test('a chip label clears AA selected as well as unselected', () {
      // A chip's label sits on two different backgrounds depending on state,
      // and the selected one is easy to miss: the chip still looks fine at a
      // glance. Fixing the label to `onSurface` measured 3.7:1 on
      // `secondaryContainer` across all four flavours.
      for (final flavor in AppFlavor.values) {
        for (final theme in [
          AppTheme.light(flavor: flavor),
          AppTheme.dark(flavor: flavor),
        ]) {
          final scheme = theme.colorScheme;
          final label = theme.chipTheme.labelStyle!.color!;

          expect(
            contrast(
              WidgetStateProperty.resolveAs<Color>(
                label,
                const {WidgetState.selected},
              ),
              scheme.secondaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '${flavor.name} selected chip on ${scheme.brightness.name}',
          );
          expect(
            contrast(
              WidgetStateProperty.resolveAs<Color>(label, const {}),
              scheme.surface,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '${flavor.name} chip on ${scheme.brightness.name}',
          );
        }
      }
    });

    test('body copy on a surface clears AA in both brightnesses', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        expect(
          contrast(theme.textTheme.bodyMedium!.color!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        // bodySmall is deliberately muted; it still has to be readable.
        expect(
          contrast(theme.textTheme.bodySmall!.color!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('the four apps are one product', () {
    test('each flavour is visibly its own', () {
      // The hue is doing one job: telling someone which of four apps is open on
      // a pile of charging tablets at the start of a shift.
      final primaries = <int>{};
      for (final flavor in AppFlavor.values) {
        primaries.add(AppTheme.light(flavor: flavor).colorScheme.primary.toARGB32());
      }
      expect(primaries.length, AppFlavor.values.length);
    });

    test('and none of them is a status colour', () {
      // Primary is chrome. If it collided with a status, a button would read as
      // a state.
      for (final flavor in AppFlavor.values) {
        for (final brightness in Brightness.values) {
          final primary = brightness == Brightness.light
              ? AppTheme.light(flavor: flavor).colorScheme.primary
              : AppTheme.dark(flavor: flavor).colorScheme.primary;
          for (final status in statuses.entries) {
            expect(
              AppStatusColors.of(status.value, brightness).toARGB32(),
              isNot(primary.toARGB32()),
              reason: '${flavor.name} primary collides with ${status.key}',
            );
          }
        }
      }
    });

    test('everything but the hue is shared', () {
      // Spacing, radii, type and touch targets are the product; the colour is
      // the label on the box.
      final waiter = AppTheme.light(flavor: AppFlavor.waiter);
      final customer = AppTheme.light(flavor: AppFlavor.customer);

      expect(waiter.textTheme.titleMedium!.fontSize,
          customer.textTheme.titleMedium!.fontSize);
      expect(waiter.filledButtonTheme.style!.minimumSize,
          customer.filledButtonTheme.style!.minimumSize);
      expect(waiter.visualDensity, customer.visualDensity);
    });

    test('the default flavour is the waiter, so AppTheme.light() is unchanged',
        () {
      expect(
        AppTheme.light().colorScheme.primary,
        AppTheme.light(flavor: AppFlavor.waiter).colorScheme.primary,
      );
    });
  });

  group('the brand panel', () {
    test('its ink clears AA on every stop of the gradient, in both brightnesses',
        () {
      // This is the test the dark mode of the hero header did not have.
      //
      // In a light Material 3 scheme `primary` is a deep tone and `onPrimary` is
      // white, which is the panel everyone pictures. In a dark scheme the roles
      // invert — `primary` becomes a pale tint meant for text — so painting the
      // same gradient there produced a bright lavender slab with dark ink on it:
      // legible, and the loudest thing on an otherwise dark screen. Dark mode
      // therefore builds the panel from `primaryContainer` and takes its ink
      // from `onPrimaryContainer`, and this holds that pairing to AA at every
      // stop rather than only at the one a screenshot happened to catch.
      for (final flavor in AppFlavor.values) {
        for (final brightness in Brightness.values) {
          final scheme = (brightness == Brightness.light
                  ? AppTheme.light(flavor: flavor)
                  : AppTheme.dark(flavor: flavor))
              .colorScheme;
          final ink = AppGradients.ink(scheme);

          for (final gradient in [
            AppGradients.hero(scheme),
            AppGradients.action(scheme),
          ]) {
            for (final stop in gradient.colors) {
              expect(
                contrast(ink, stop),
                greaterThanOrEqualTo(4.5),
                reason: '${flavor.name} ${brightness.name}: ink on '
                    '${stop.toARGB32().toRadixString(16)}',
              );
            }
          }
        }
      }
    });

    test('it is a panel, not a lamp: never brighter than a dark canvas expects',
        () {
      // A brand header is chrome. On a dark scheme it must not out-glow the
      // content it sits above — the figures are the point of the screen, and a
      // header measured at 0.175 luminance against a 0.007 canvas was the
      // brightest thing on it.
      for (final flavor in AppFlavor.values) {
        final scheme = AppTheme.dark(flavor: flavor).colorScheme;
        for (final stop in AppGradients.hero(scheme).colors) {
          expect(
            stop.computeLuminance(),
            lessThan(0.16),
            reason: '${flavor.name} dark header stop is too bright',
          );
        }
      }
    });

    test('a control on the panel keeps a platform-legal target', () {
      // 44 looked better in a row of three and failed the waiter app's
      // accessibility suite on the spot. The header is chrome, but chrome is
      // still tapped.
      expect(AppSizes.chromeTouchTarget, greaterThanOrEqualTo(48));
    });
  });

  group('touch targets', () {
    test('every button style clears the service-floor minimum', () {
      // Material says 48. Staff moving quickly mis-tap at that size, and a
      // mis-tap here means a wrong dish or a double charge.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final size in [
          theme.filledButtonTheme.style?.minimumSize,
          theme.outlinedButtonTheme.style?.minimumSize,
          theme.textButtonTheme.style?.minimumSize,
        ]) {
          expect(
            size?.resolve({})?.height,
            greaterThanOrEqualTo(AppSizes.minTouchTarget),
          );
        }
      }
    });
  });

  group('a status badge', () {
    testWidgets('resolves its colour for the surface it lands on',
        (tester) async {
      // Same badge, both themes: the label must not come out the same colour,
      // because the two surfaces are opposites.
      final inks = <Color>[];

      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: StatusBadge(
                label: 'Settled',
                color: AppStatusColors.settled,
                icon: Icons.payments_outlined,
              ),
            ),
          ),
        );
        // MaterialApp lerps between themes over kThemeAnimationDuration, so a
        // single pump still reads mostly the previous brightness.
        await tester.pumpAndSettle();
        inks.add(tester.widget<Text>(find.text('Settled')).style!.color!);
      }

      expect(inks[0], isNot(inks[1]));
      expect(inks[1].computeLuminance(), greaterThan(inks[0].computeLuminance()));
    });

    testWidgets('still says the word as well as showing the colour',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: StatusBadge(
              label: 'Ready',
              color: AppStatusColors.ready,
              icon: Icons.room_service_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byIcon(Icons.room_service_outlined), findsOneWidget);
    });
  });

  group('motion yields to the platform', () {
    testWidgets('reduced motion collapses durations to zero', (tester) async {
      late Duration honoured;
      late Duration ignored;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(builder: (context) {
              honoured = AppMotion.of(context);
              return const SizedBox.shrink();
            }),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            ignored = AppMotion.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );

      expect(honoured, Duration.zero);
      expect(ignored, AppMotion.normal);
    });

    testWidgets('a skeleton renders without animating when asked not to',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: SkeletonList(rows: 3)),
          ),
        ),
      );

      // No ShaderMask, and — the point of the check — pumpAndSettle returns,
      // which it cannot do while a repeating controller is running.
      expect(find.byType(ShaderMask), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('breakpoints', () {
    testWidgets('name the device class, not a pixel count', (tester) async {
      Future<(bool, bool)> at(double width) async {
        late bool compact;
        late bool expanded;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Builder(builder: (context) {
              compact = AppBreakpoints.isCompact(context);
              expanded = AppBreakpoints.isExpanded(context);
              return const SizedBox.shrink();
            }),
          ),
        );
        return (compact, expanded);
      }

      // Material's own window size classes, so a decision made here matches
      // what the platform does at the same width rather than disagreeing with
      // it by forty pixels.
      expect(await at(390), (true, false)); // phone portrait
      expect(await at(700), (false, false)); // large phone landscape
      expect(await at(834), (false, false)); // 10" tablet portrait — medium
      expect(await at(1194), (false, true)); // 10" tablet landscape
    });
  });
}
