import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// This app's own copy, with an English fallback.
///
/// Mirrors `strings(context)` in `rms_core`, and for the same reason: a widget
/// test that pumps a bare `MaterialApp` gets English rather than a null-check
/// crash, so screens can be localised one at a time.
AppText appText(BuildContext context) =>
    Localizations.of<AppText>(context, AppText) ?? AppTextEn();
