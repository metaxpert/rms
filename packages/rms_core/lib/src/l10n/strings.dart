import 'package:flutter/widgets.dart';

import 'rms_localizations.dart';
import 'rms_localizations_en.dart';

/// The shared strings, with an English fallback.
///
/// `RmsLocalizations.of(context)` requires the delegate to be installed. This
/// wrapper does not: an app — or a widget test — that has not yet registered it
/// gets English instead of a null-check crash.
///
/// That is deliberate, and it is what makes the localisation rollout
/// incremental rather than a flag day. A screen can start reading translated
/// strings before every app has been wired up, and nothing breaks in between.
RmsLocalizations strings(BuildContext context) =>
    Localizations.of<RmsLocalizations>(context, RmsLocalizations) ??
    RmsLocalizationsEn();
