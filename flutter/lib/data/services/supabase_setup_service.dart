import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_schema.dart';

/// Outcome of a [SupabaseSetupService.check] or
/// [SupabaseSetupService.install] call.
class SupabaseSetupResult {
  /// Machine-readable outcome; `null` when the call succeeded. Mirrors the
  /// Electron side's codes one-for-one so both UIs read the same list:
  /// no_config, invalid_url, bad_key, unreachable, network, needs_manual,
  /// bad_access_token, forbidden, no_project_ref, rate_limited, sql_error.
  final String? code;
  final bool ready;
  final int installedVersion;
  final Map<String, bool> objects;

  /// Whether the project has Google as an enabled auth provider — advisory,
  /// since that is a dashboard toggle no SQL can flip. `null` when unknown.
  final bool? googleProvider;

  const SupabaseSetupResult({
    this.code,
    this.ready = false,
    this.installedVersion = 0,
    this.objects = const {},
    this.googleProvider,
  });

  bool get ok => code == null;
  int get missing => objects.values.where((v) => !v).length;
}

/// "Bring your own Supabase project" — the Flutter/PWA counterpart of the
/// Electron app's Setting → App Data → Supabase Project page
/// (electron/src/db/supabase-setup.js). Same contract, same SQL: both sides
/// embed `src/supabase/setup/dracondex_setup.sql` through
/// `src/supabase/setup/gen.mjs`, so a project set up from either app is
/// already set up for the other.
///
/// Two things happen here, and only the first works off the publishable key:
///
///  * [check]   — reachable? key accepted? which of the tables and functions
///                Cloud Sync needs are present? Answered by the anon-callable
///                `dracondex_schema_status()` probe the setup SQL installs;
///                until that exists the answer is "nothing installed", which
///                is exactly what a fresh project should report.
///  * [install] — a publishable key is public by design and PostgREST exposes
///                no DDL through it, so creating tables needs either a
///                personal access token (run through the Management API here,
///                used once and never stored) or the user pasting [setupSql]
///                into their project's SQL editor by hand.
///
/// Everything is plain https + shared_preferences, so this file works
/// unchanged on Android and on the web/PWA build (docs/PWA.md) — Supabase and
/// api.supabase.com both send permissive CORS headers.
class SupabaseSetupService {
  static const _urlKey = 'supabase_url';
  static const _anonKey = 'supabase_anon_key';
  static const _mgmtApi = 'https://api.supabase.com';
  static const _timeout = Duration(seconds: 20);
  static const _installTimeout = Duration(seconds: 60);

  static String get setupSql => kSupabaseSetupSql;
  static int get requiredVersion => kSupabaseSchemaVersion;

  // --- config -------------------------------------------------------------

  static Future<String> loadUrl() async =>
      (await SharedPreferences.getInstance()).getString(_urlKey) ?? '';

  static Future<String> loadKey() async =>
      (await SharedPreferences.getInstance()).getString(_anonKey) ?? '';

  static Future<bool> isConfigured() async =>
      (await loadUrl()).isNotEmpty && (await loadKey()).isNotEmpty;

  /// An empty [key] keeps whatever is already stored — the setup sheet never
  /// pre-fills the key field, so a blank box means "leave it alone".
  /// Returns null on success, or an error code.
  static Future<String?> save(String url, String key) async {
    final cleanUrl = _normalizeUrl(url);
    if (cleanUrl.isEmpty) return 'no_config';
    if (!_isAllowedUrl(cleanUrl)) return 'invalid_url';
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = key.trim().isNotEmpty ? key.trim() : (prefs.getString(_anonKey) ?? '');
    if (cleanKey.isEmpty) return 'no_config';
    await prefs.setString(_urlKey, cleanUrl);
    await prefs.setString(_anonKey, cleanKey);
    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKey);
  }

  static String _normalizeUrl(String url) {
    var s = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// The stored URL is where auth tokens and whole-vault snapshots would be
  /// sent, so https only — same rule the Electron side enforces in sync.js.
  static bool _isAllowedUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasAuthority) return false;
    if (u.scheme == 'https') return true;
    return u.scheme == 'http' && (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1');
  }

  /// The subdomain of a hosted project (https://&lt;ref&gt;.supabase.co).
  /// Self-hosted projects have none, which costs them only the Management API
  /// install and the dashboard links; the manual path still works.
  static String? projectRef(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    final m = RegExp(r'^([a-z0-9]{16,40})\.supabase\.(co|in|red)$').firstMatch(host);
    return m?.group(1);
  }

  static Uri? dashboardUri(String page, String url) {
    final ref = projectRef(url);
    switch (page) {
      case 'tokens':
        return Uri.parse('https://supabase.com/dashboard/account/tokens');
      case 'sql':
        return ref == null ? null : Uri.parse('https://supabase.com/dashboard/project/$ref/sql/new');
      case 'auth':
        return ref == null ? null : Uri.parse('https://supabase.com/dashboard/project/$ref/auth/providers');
      case 'api':
        return ref == null ? null : Uri.parse('https://supabase.com/dashboard/project/$ref/settings/api');
      default:
        return null;
    }
  }

  // --- check --------------------------------------------------------------

  /// [url]/[key] override the stored config so the sheet can test what the
  /// user has typed before committing it.
  static Future<SupabaseSetupResult> check({String? url, String? key}) async {
    final base = _normalizeUrl(url ?? await loadUrl());
    final apikey = (key?.trim().isNotEmpty ?? false) ? key!.trim() : await loadKey();
    if (base.isEmpty || apikey.isEmpty) return const SupabaseSetupResult(code: 'no_config');
    if (!_isAllowedUrl(base)) return const SupabaseSetupResult(code: 'invalid_url');

    // Step 1 — reachable, and the key accepted. PostgREST's root document
    // doubles as a fallback list of exposed RPCs for a project that was set
    // up from the old migration files and so has the functions but not the
    // status probe.
    http.Response root;
    try {
      root = await http.get(Uri.parse('$base/rest/v1/'), headers: {'apikey': apikey}).timeout(_timeout);
    } catch (_) {
      return const SupabaseSetupResult(code: 'network');
    }
    if (root.statusCode == 401 || root.statusCode == 403) {
      return const SupabaseSetupResult(code: 'bad_key');
    }
    if (root.statusCode >= 400) return const SupabaseSetupResult(code: 'unreachable');
    final exposedRpc = <String>{};
    final openapi = _decode(root.body);
    final paths = openapi is Map ? openapi['paths'] : null;
    if (paths is Map) {
      for (final p in paths.keys) {
        final s = p.toString();
        if (s.startsWith('/rpc/')) exposedRpc.add(s.substring(5));
      }
    }

    // Step 2 — the probe. Its absence IS the answer ("not installed yet"), so
    // a 404 here is a result, not a failure.
    Map<String, dynamic>? status;
    try {
      final probe = await http.post(
        Uri.parse('$base/rest/v1/rpc/dracondex_schema_status'),
        headers: {'apikey': apikey, 'Authorization': 'Bearer $apikey', 'Content-Type': 'application/json'},
        body: '{}',
      ).timeout(_timeout);
      if (probe.statusCode < 300) {
        final decoded = _decode(probe.body);
        if (decoded is Map<String, dynamic>) status = decoded;
      }
    } catch (_) {
      return const SupabaseSetupResult(code: 'network');
    }

    final tables = (status?['tables'] as Map?) ?? const <String, dynamic>{};
    final functions = (status?['functions'] as Map?) ?? const <String, dynamic>{};
    final objects = <String, bool>{
      for (final t in kSupabaseRequiredTables) t: tables[t] == true,
      // Either source is proof enough: the probe's catalog lookup, or
      // PostgREST advertising the endpoint.
      for (final f in kSupabaseRequiredFunctions) f: functions[f] == true || exposedRpc.contains(f),
      'dracondex_schema_status': status != null,
    };
    final installedVersion = int.tryParse('${status?['schema_version'] ?? 0}') ?? 0;

    bool? google;
    try {
      final s = await http.get(Uri.parse('$base/auth/v1/settings'), headers: {'apikey': apikey}).timeout(_timeout);
      final decoded = _decode(s.body);
      final external = decoded is Map ? decoded['external'] : null;
      if (external is Map && external['google'] is bool) google = external['google'] as bool;
    } catch (_) {
      // Advisory only — a failure here must not fail the whole check.
    }

    return SupabaseSetupResult(
      ready: !objects.containsValue(false) && installedVersion >= kSupabaseSchemaVersion,
      installedVersion: installedVersion,
      objects: objects,
      googleProvider: google,
    );
  }

  // --- install ------------------------------------------------------------

  /// Runs [setupSql] against the project through the Management API.
  /// [accessToken] is a Supabase personal access token (sbp_…); it is used for
  /// this one request and is never written to shared_preferences or a log.
  static Future<SupabaseSetupResult> install(String accessToken, {String? url, String? key}) async {
    final base = _normalizeUrl(url ?? await loadUrl());
    if (base.isEmpty) return const SupabaseSetupResult(code: 'no_config');
    final token = accessToken.trim();
    if (token.isEmpty) return const SupabaseSetupResult(code: 'needs_manual');
    final ref = projectRef(base);
    if (ref == null) return const SupabaseSetupResult(code: 'no_project_ref');

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$_mgmtApi/v1/projects/$ref/database/query'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'query': kSupabaseSetupSql}),
      ).timeout(_installTimeout);
    } catch (_) {
      return const SupabaseSetupResult(code: 'network');
    }
    if (res.statusCode == 401) return const SupabaseSetupResult(code: 'bad_access_token');
    if (res.statusCode == 403) return const SupabaseSetupResult(code: 'forbidden');
    if (res.statusCode == 404) return const SupabaseSetupResult(code: 'no_project_ref');
    if (res.statusCode == 429) return const SupabaseSetupResult(code: 'rate_limited');
    if (res.statusCode >= 300) return const SupabaseSetupResult(code: 'sql_error');

    // Trust nothing: "installed" means the same probe the check button uses
    // now reports every object present.
    return check(url: url, key: key);
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
