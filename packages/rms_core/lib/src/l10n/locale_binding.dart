import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Ties `package:intl`'s formatting to the locale the app is actually showing.
///
/// Flutter's `localizationsDelegates` translate *strings*; they do nothing for
/// `DateFormat` and `NumberFormat`, which read `Intl.defaultLocale`. Left
/// unset — as it was — every timestamp formats as `en_US` however the rest of
/// the app is rendered.
///
/// That was invisible while the only second locale was Urdu, whose CLDR data
/// happens to use the same 24-hour clock and Latin digits Pakistan writes
/// anyway. It would not have stayed invisible.
///
/// Wrap the app's content in this and the two libraries stay in step.
class LocaleBinding extends StatelessWidget {
  const LocaleBinding({super.key, required this.child});

  final Widget child;

  /// Load the date symbols for every supported locale.
  ///
  /// Called once from `main()`, before the first frame: `DateFormat` throws on
  /// a locale whose symbols were never loaded, and a crash on a timestamp is a
  /// poor way to discover a translation shipped.
  static Future<void> ensureInitialised() => initializeDateFormatting();

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
    return child;
  }
}
