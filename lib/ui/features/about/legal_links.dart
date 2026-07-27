import 'package:flutter/widgets.dart';

/// GitHub-hosted legal document URLs for the in-app About page.
///
/// Opens in SFSafariViewController / Chrome Custom Tabs via [openMarkdownLink].
abstract final class LegalLinks {
  static const _repoBase =
      'https://github.com/Ykworm/thktree/blob/master/docs/legal';

  static const license =
      'https://github.com/Ykworm/thktree/blob/master/LICENSE';

  /// Resolves `zh` vs `en` from saved app locale, then system locale.
  static String languageCode({Locale? savedLocale, required Locale systemLocale}) {
    final code = savedLocale?.languageCode ?? systemLocale.languageCode;
    return code.startsWith('zh') ? 'zh' : 'en';
  }

  static String privacyPolicy({Locale? savedLocale, required Locale systemLocale}) {
    final lang = languageCode(savedLocale: savedLocale, systemLocale: systemLocale);
    return lang == 'zh'
        ? '$_repoBase/privacy-policy-zh.md'
        : '$_repoBase/privacy-policy-en.md';
  }

  static String termsOfService({Locale? savedLocale, required Locale systemLocale}) {
    final lang = languageCode(savedLocale: savedLocale, systemLocale: systemLocale);
    return lang == 'zh'
        ? '$_repoBase/terms-of-service-zh.md'
        : '$_repoBase/terms-of-service-en.md';
  }
}
