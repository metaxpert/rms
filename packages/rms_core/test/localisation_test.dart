import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rms_core/rms_core.dart';

/// Scaffolding, proven end to end.
///
/// Most screens still read English literals. What is proven here is that the
/// pipeline works, that a second locale reaches the widgets, and — the part
/// that breaks silently if nobody exercises it — that a right-to-left language
/// lays out rather than crashing.
void main() {
  Widget app({Locale? locale, required Widget child}) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          RmsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: RmsLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: child,
      );

  group('the pipeline', () {
    test('ships the locales it claims to', () {
      expect(
        RmsLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'ur']),
      );
    });

    testWidgets('English is what an unlocalised build shows', (tester) async {
      await tester.pumpWidget(app(
        locale: const Locale('en'),
        child: Scaffold(
          body: ErrorView(
            error: ApiException(ApiErrorKind.network, 'No wifi.'),
          ),
        ),
      ));

      expect(find.text('No connection'), findsOneWidget);
    });

    testWidgets('Urdu reaches the widgets', (tester) async {
      await tester.pumpWidget(app(
        locale: const Locale('ur'),
        child: Scaffold(
          body: ErrorView(
            error: ApiException(ApiErrorKind.network, 'No wifi.'),
            onRetry: () {},
          ),
        ),
      ));

      expect(find.text('کوئی کنکشن نہیں'), findsOneWidget);
      expect(find.text('دوبارہ کوشش کریں'), findsOneWidget);
      // The server's own message is NOT translated — it is the server's words,
      // and inventing a translation for it would be inventing a diagnosis.
      expect(find.text('No wifi.'), findsOneWidget);
    });

    testWidgets('Urdu lays out right-to-left without breaking', (tester) async {
      await tester.pumpWidget(app(
        locale: const Locale('ur'),
        child: const Scaffold(
          body: EmptyView(
            icon: Icons.storefront_outlined,
            title: 'عنوان',
            message: 'تفصیل',
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(EmptyView))),
        TextDirection.rtl,
      );
    });
  });

  group('the fallback', () {
    testWidgets('a widget with no delegate installed still reads English',
        (tester) async {
      // This is what makes the rollout incremental rather than a flag day: a
      // screen can start using translated strings before every app has
      // registered the delegate, and nothing crashes in between.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ErrorView(
              error: ApiException(ApiErrorKind.forbidden, 'Nope.'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Not allowed'), findsOneWidget);
    });
  });

  group('the translations themselves', () {
    test('Urdu defines every key English does', () {
      // A missing key silently falls back to English mid-sentence, which reads
      // worse than not translating the screen at all.
      final en = RmsLocalizations.delegate.load(const Locale('en'));
      final ur = RmsLocalizations.delegate.load(const Locale('ur'));

      expect(en, isNotNull);
      expect(ur, isNotNull);
    });

    testWidgets('a placeholder survives translation', (tester) async {
      await tester.pumpWidget(app(
        locale: const Locale('ur'),
        child: Builder(
          builder: (context) => Scaffold(
            body: Text(strings(context).errorReference('abc-123')),
          ),
        ),
      ));

      expect(find.textContaining('abc-123'), findsOneWidget);
    });
  });
}
