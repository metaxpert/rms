import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// This app's own copy, with an English fallback — see the note in `rms_core`'s
/// `strings()` for why the fallback exists.
AppText appText(BuildContext context) =>
    Localizations.of<AppText>(context, AppText) ?? AppTextEn();
