import 'package:flutter/widgets.dart';

import '../../providers/app_preferences_provider.dart';

/// Picks the text for the current app language from a [BuildContext].
String ctr(BuildContext c, String en, String ha, String fr, String pcm) =>
    c.appLanguage.tr(en: en, ha: ha, fr: fr, pcm: pcm);
