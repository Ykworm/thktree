import 'package:package_info_plus/package_info_plus.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

PackageInfo? _cachedPackageInfo;

/// Loads [PackageInfo] once and caches it for the process lifetime.
Future<PackageInfo> loadPackageInfo() {
  final cached = _cachedPackageInfo;
  if (cached != null) return Future.value(cached);
  return PackageInfo.fromPlatform().then((info) => _cachedPackageInfo = info);
}

/// Semver from pubspec, e.g. `0.9.0` — for export manifests and backups.
Future<String> loadAppVersionString() async =>
    (await loadPackageInfo()).version;

/// User-facing label, e.g. `0.9.0 (Beta)`.
String formatVersionLabel(AppLocalizations l10n, String version) =>
    '$version ${l10n.aboutVersionBeta}';
