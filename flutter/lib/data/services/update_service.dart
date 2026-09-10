import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the latest GitHub Release for this app from the project's PUBLIC
/// release mirror (see docs/UPDATE.md) and offers it to the user. On Android this app IS able to install its own
/// update directly — a sideloaded APK has no store to defer to — via
/// apk_installer.dart's downloadApk()/installApk(), which hand the file to
/// Android's own package installer; nothing here silently auto-installs
/// anything without the user tapping "Install now" and going through that
/// system install prompt. That download/install code lives in a separate,
/// conditionally-compiled file (not this one) because it needs dart:io's
/// File, which is unavailable on the web build this class is also used by.
class UpdateAsset {
  final String name;
  final String downloadUrl;
  const UpdateAsset({required this.name, required this.downloadUrl});
}

class UpdateInfo {
  final String version;
  final String notes;
  final String url;
  final List<UpdateAsset> assets;
  const UpdateInfo({required this.version, required this.notes, required this.url, this.assets = const []});
}

class UpdateCheckResult {
  final bool available;
  final bool dismissed;
  final String current;
  final UpdateInfo? update;
  const UpdateCheckResult({required this.available, required this.dismissed, required this.current, this.update});
}

class UpdateService {
  // This app's own canonical release feed — every install reads the SAME one.
  //
  // NOT the source repo (ZYDRAXYL/DraconDex-APP): that one is PRIVATE, and the
  // GitHub REST API answers 404 to every unauthenticated caller — which is
  // every install of this app. _fetchLatest() below turns any non-200 into
  // "no update", so the check reported "you are on the latest version" no
  // matter how many releases had shipped. Releases are therefore mirrored to
  // a public repo by .github/scripts/mirror-release.sh (run from the `mirror`
  // job in build-apk.yml / build-electron.yml), and this check reads that
  // mirror. See docs/UPDATE.md section 2.12.
  //
  // That mirror is ZYDRAXYL/DraconDex-WEB — the website repo, which is also where
  // the download page's own release data comes from. It used to be a separate
  // releases-only repo, ZYDRAXYL/DraconDex-REL; pointing both consumers at
  // one mirror means a release only has to land in one place to be visible
  // everywhere, and one token to keep alive instead of two. The assets are the
  // same files either way, mirrored by the same script.
  // FORKERS: a fork MUST edit this to its own repo, or the update check
  // reports the upstream project's releases.
  static const _repo = 'ZYDRAXYL/DraconDex-WEB';
  // NOT /releases/latest: the mirror carries the Electron app's own releases
  // (tag vX.Y.Z, see electron/src/db/update.js) alongside this app's, exactly
  // as the source repo does. /releases/latest returns the single
  // most-recently-published non-draft/non-prerelease release across the WHOLE
  // repo regardless of which product it belongs to, so a same-day electron
  // vX.Y.Z release can shadow a genuinely newer flutter-vX.Y.Z one (or the
  // reverse) — and worse, an electron tag like "v4.10.1" parses as a
  // *valid-looking* version here once a leading "v" is stripped, so this app
  // could offer to "update" to an Electron release and hand the user a
  // desktop installer. List releases instead and only accept tags in this
  // app's own flutter-v* namespace. per_page is generous because BOTH trains
  // share the list and the newest release of one may sit well down it.
  static const _releasesUrl = 'https://api.github.com/repos/$_repo/releases?per_page=100';
  // Every URL this service is willing to open must start with this — pinning
  // the host alone isn't enough; the path prefix is what keeps a compromised
  // or unexpected API response from pointing anywhere else.
  static const releaseUrlPrefix = 'https://github.com/$_repo/releases';
  // Where this repo's own release assets live. Every asset this service will
  // download must sit under it.
  static const assetUrlPrefix = '$releaseUrlPrefix/download/';
  static const _notesMax = 4000;
  static const _seenKey = 'update_seen_version';

  // This app's own release tag namespace (see .github/workflows/build-apk.yml)
  // — distinct from the Electron app's plain vX.Y.Z tags in the same repo.
  static final RegExp _tagPrefixRe = RegExp(r'^flutter-v', caseSensitive: false);
  static final RegExp _tagRe = RegExp(r'^\d+(\.\d+){0,3}$');

  /// The response is remote data, so every field is validated, never
  /// trusted: the tag must belong to this app's own release namespace and
  /// look like a version, and the URL must live under this repo's own
  /// releases path. Returning null means "no update", the same path every
  /// other failure below takes. Public (not `_`-private) so tests can
  /// exercise it directly against real/malformed API payloads, same as
  /// electron/test/update-release.test.mjs does for the JS side.
  static UpdateInfo? parseRelease(Map<String, dynamic> json) {
    final rawTag = json['tag_name'] as String? ?? '';
    if (!_tagPrefixRe.hasMatch(rawTag)) return null;
    final version = rawTag.replaceFirst(_tagPrefixRe, '').trim();
    if (!_tagRe.hasMatch(version)) return null;
    final htmlUrl = json['html_url'] as String? ?? '';
    final url = htmlUrl.startsWith('$releaseUrlPrefix/') ? htmlUrl : releaseUrlPrefix;
    final notes = json['body'] as String? ?? '';
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    // Asset URLs get the same treatment as html_url above, and for a stronger
    // reason: html_url only reaches a browser, while these are fetched and —
    // in the APK's case — handed to Android's package installer. Pinning the
    // full download prefix (not just the host) is what keeps an unexpected API
    // response from pointing the installer at someone else's file.
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((a) => UpdateAsset(name: a['name'] as String? ?? '', downloadUrl: a['browser_download_url'] as String? ?? ''))
        .where((a) => a.name.isNotEmpty && a.downloadUrl.startsWith(assetUrlPrefix))
        .toList();
    return UpdateInfo(
      version: version,
      notes: notes.length > _notesMax ? notes.substring(0, _notesMax) : notes,
      url: url,
      assets: assets,
    );
  }

  /// Picks the HIGHEST version in this app's own tag namespace — deliberately
  /// not the first list entry.
  ///
  /// GET /releases is ordered by the release's created_at, and a release's
  /// created_at is the date of the COMMIT its tag points at, not the date it
  /// was published. Tag a fix that sits on an older commit and its release
  /// sorts below releases published days earlier: in the real feed
  /// flutter-v2.10.0 and flutter-v2.10.1 both landed underneath
  /// flutter-v2.9.0, so "first match wins" reported 2.9.0 as the latest
  /// release and every 2.9 install was told it was up to date while 2.10.1
  /// was already out. Comparing versions has no such failure mode. Pure
  /// (list in, release out) so it's testable without mocking http — see
  /// update_service_test.dart.
  static UpdateInfo? pickOwnRelease(List<dynamic> list) {
    UpdateInfo? best;
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      if (item['draft'] == true || item['prerelease'] == true) continue;
      final parsed = parseRelease(item);
      if (parsed == null) continue;
      // Ties keep the earlier entry, i.e. the one GitHub itself ranks first.
      if (best == null || isNewerVersion(parsed.version, best.version)) best = parsed;
    }
    return best;
  }

  static Future<UpdateInfo?> _fetchLatest(String currentVersion) async {
    try {
      // Unlike /releases/latest, the list endpoint includes drafts and
      // prereleases, so both are filtered out inside pickOwnRelease(). The
      // API rejects requests without a User-Agent.
      final res = await http.get(
        Uri.parse(_releasesUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'DraconDex/$currentVersion',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body);
      if (list is! List) return null;
      return pickOwnRelease(list);
    } catch (_) {
      return null;
    }
  }

  static String _stripSuffix(String v) => v.split('-').first.split('+').first;
  static List<int> _parts(String v) => _stripSuffix(v).split('.').map((n) => int.tryParse(n) ?? 0).toList();

  static bool isNewerVersion(String remote, String local) {
    final r = _parts(remote), l = _parts(local);
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Never throws — network failure, a non-200, bad JSON, or a malformed
  /// release all fall through to "no update available", so an offline
  /// launch never shows an error.
  static Future<UpdateCheckResult> checkForUpdate() async {
    String current;
    try {
      current = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      current = '0.0.0';
    }
    final latest = await _fetchLatest(current);
    if (latest == null || !isNewerVersion(latest.version, current)) {
      return UpdateCheckResult(available: false, dismissed: false, current: current);
    }
    var dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = (prefs.getString(_seenKey) ?? '') == latest.version;
    } catch (_) {}
    return UpdateCheckResult(available: true, dismissed: dismissed, current: current, update: latest);
  }

  static Future<void> dismiss(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, version);
    } catch (_) {}
  }

  /// The universal (all-ABI) release APK for [info]'s version — see the
  /// "Collect release assets" step in .github/workflows/build-apk.yml. This
  /// is picked over an ABI-specific split so no device-ABI detection is
  /// needed, at the cost of a larger download. Null if the release has no
  /// such asset (e.g. an older release published before assets were
  /// attached), in which case the caller should fall back to the browser.
  static UpdateAsset? apkAsset(UpdateInfo info) {
    final name = 'DraconDex-${info.version}-release.apk';
    for (final a in info.assets) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// The `checksums-sha256.txt` the release workflow publishes next to the
  /// APKs (same "Collect release assets" step). apk_installer_io.dart hashes
  /// what it downloaded and compares against this before handing the file to
  /// Android's package installer: a 68 MB download that silently truncates
  /// produces a file the installer rejects with nothing but its generic
  /// "invalid package" message, which is indistinguishable from a genuinely
  /// broken build unless the app checks first. Null for releases published
  /// before the checksums file existed — the download then proceeds unhashed
  /// rather than failing, since a length check still applies.
  static UpdateAsset? checksumsAsset(UpdateInfo info) {
    for (final a in info.assets) {
      if (a.name == checksumsName) return a;
    }
    return null;
  }

  static const checksumsName = 'checksums-sha256.txt';

  // `sha256sum <files>` output: 64 hex digits, whitespace, an optional "*"
  // binary-mode marker, then the file name.
  static final RegExp _sumLineRe = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');

  /// The expected digest of [fileName] from `sha256sum` output, lowercased,
  /// or null if that file is not listed. Pure so it is testable against real
  /// workflow output — see update_service_test.dart.
  static String? expectedSha256(String checksums, String fileName) {
    for (final line in const LineSplitter().convert(checksums)) {
      final m = _sumLineRe.firstMatch(line.trim());
      if (m != null && m.group(2)!.trim() == fileName) {
        return m.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  /// Fetches and parses the expected digest for [asset] from [info]'s
  /// checksums file. Returns null whenever the digest simply is not
  /// available (no checksums asset, fetch failed, file not listed) — the
  /// caller treats that as "cannot verify", not as "verification failed",
  /// so a GitHub hiccup does not block an otherwise fine install.
  static Future<String?> fetchExpectedSha256(UpdateInfo info, UpdateAsset asset) async {
    final sums = checksumsAsset(info);
    if (sums == null) return null;
    try {
      final res = await http
          .get(Uri.parse(sums.downloadUrl), headers: {'User-Agent': 'DraconDex/${info.version}'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return expectedSha256(res.body, asset.name);
    } catch (_) {
      return null;
    }
  }
}
