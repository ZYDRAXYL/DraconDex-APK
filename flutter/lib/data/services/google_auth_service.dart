import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'google_auth_common.dart';
import 'google_auth_platform.dart';

export 'google_auth_common.dart' show GoogleAuthException, googleOAuthScope;

/// The OAuth client the user created in their own Google Cloud project.
///
/// Bring-your-own credentials, exactly like the Electron app's Drive config
/// (electron/src/db/drive.js getDriveConfig) and like the Supabase project
/// setup next to it in Settings: this repo is open source, so it has nowhere
/// to hide a client secret, and a shared client would put every fork's users
/// on one quota and one consent screen.
class GoogleAuthConfig {
  final String clientId;
  final String clientSecret;
  const GoogleAuthConfig({this.clientId = '', this.clientSecret = ''});

  /// Web clients get no secret from Google at all, so requiring one there
  /// would make the form impossible to complete.
  bool get isConfigured =>
      clientId.isNotEmpty && (!googleAuthUsesRefreshToken || clientSecret.isNotEmpty);
}

/// What the UI needs to draw the account row without caring which flow ran.
class GoogleConnection {
  final String? email;
  final bool connected;

  /// Web only: a grant that was completed but whose access token has since
  /// run out. Worth telling apart from "never connected" because getting
  /// back is one click with no consent screen.
  final bool expired;

  const GoogleConnection({this.email, this.connected = false, this.expired = false});

  static const none = GoogleConnection();
}

/// Google login shared by every Flutter build target — Android, iOS, desktop
/// and the web/PWA build. Owns the stored credentials, the token cache and
/// the email lookup; the part that differs per target (how the consent
/// screen opens and answers) lives behind google_auth_platform.dart.
class GoogleAuthService {
  static const _kClientId = 'google_client_id';
  static const _kClientSecret = 'google_client_secret';
  static const _kRefreshToken = 'google_refresh_token';
  static const _kAccessToken = 'google_access_token';
  static const _kAccessExpiry = 'google_access_expires_at';
  static const _kEmail = 'google_email';

  /// Refreshed a minute early so a token cannot expire mid-request.
  static const _skew = Duration(seconds: 60);

  static bool get needsClientSecret => googleAuthUsesRefreshToken;

  /// Non-null on web: the exact redirect URI to register on the Google
  /// Cloud OAuth client. Native picks a fresh loopback port per login and
  /// needs nothing registered.
  static String? get redirectUriHint => googleAuthRedirectUriHint();

  static Future<GoogleAuthConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return GoogleAuthConfig(
      clientId: prefs.getString(_kClientId) ?? '',
      clientSecret: prefs.getString(_kClientSecret) ?? '',
    );
  }

  /// [clientSecret] empty means "keep the stored one" so the setup screen can
  /// leave the secret field blank instead of putting it back on screen —
  /// same rule as SupabaseSetupService.save.
  static Future<void> saveConfig({required String clientId, String clientSecret = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = clientId.trim();
    final previousId = prefs.getString(_kClientId) ?? '';
    await prefs.setString(_kClientId, id);
    if (clientSecret.trim().isNotEmpty) {
      await prefs.setString(_kClientSecret, clientSecret.trim());
    }
    // Tokens belong to the client that issued them — keeping them across a
    // client change would leave the account row showing an email that no
    // request can actually use.
    if (previousId.isNotEmpty && previousId != id) await _clearSession(prefs);
  }

  static Future<GoogleConnection> connection() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kEmail);
    if (googleAuthUsesRefreshToken) {
      final hasRefresh = (prefs.getString(_kRefreshToken) ?? '').isNotEmpty;
      return hasRefresh
          ? GoogleConnection(email: email, connected: true)
          : GoogleConnection.none;
    }
    if (_cachedTokenIsUsable(prefs)) return GoogleConnection(email: email, connected: true);
    // A remembered email with no live token is the web session having aged
    // out, not a fresh install.
    if (email != null && email.isNotEmpty) {
      return GoogleConnection(email: email, expired: true);
    }
    return GoogleConnection.none;
  }

  /// Call this from the click handler itself, before any `await`, then call
  /// [connect]. On web it reserves the consent popup while the user gesture
  /// is still live (see googleAuthPrepare); elsewhere it does nothing.
  static void beginInteractive() => googleAuthPrepare();

  /// Runs the interactive login and returns the signed-in email (empty
  /// string if Google's userinfo call did not answer — the connection still
  /// stands, there is just nothing to display). Throws [GoogleAuthException].
  static Future<String> connect() async {
    final config = await loadConfig();
    if (!config.isConfigured) {
      googleAuthCancelPrepare();
      throw const GoogleAuthException('no_config');
    }

    final GoogleAuthSession session;
    try {
      session = await googleAuthAuthorize(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
      );
    } catch (_) {
      // authorize() clears the reservation once it takes it, so this only
      // closes a popup that never became a consent screen.
      googleAuthCancelPrepare();
      rethrow;
    }
    if (googleAuthUsesRefreshToken && session.refreshToken == null) {
      // Only reachable if Google withheld it despite prompt=consent; without
      // one, "connected" would silently stop working in an hour.
      throw const GoogleAuthException('auth', 'no_refresh_token');
    }

    final prefs = await SharedPreferences.getInstance();
    await _storeSession(prefs, session);

    final email = await _fetchEmail(session.accessToken);
    await prefs.setString(_kEmail, email);
    return email;
  }

  static Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kRefreshToken) ?? prefs.getString(_kAccessToken) ?? '';
    if (token.isNotEmpty) await googleAuthRevoke(token);
    await _clearSession(prefs);
  }

  /// A usable access token, refreshing first if the cached one has run out.
  /// Throws `GoogleAuthException('not_connected')` when there is nothing to
  /// refresh from — on web that is also what an aged-out session looks like.
  static Future<String> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cachedTokenIsUsable(prefs)) return prefs.getString(_kAccessToken)!;

    final refreshToken = prefs.getString(_kRefreshToken) ?? '';
    if (refreshToken.isEmpty) throw const GoogleAuthException('not_connected');

    final config = await loadConfig();
    if (!config.isConfigured) throw const GoogleAuthException('no_config');

    GoogleAuthSession? session;
    try {
      session = await googleAuthRefresh(
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        refreshToken: refreshToken,
      );
    } on GoogleAuthException catch (e) {
      // A refusal from Google means the grant is gone (revoked from the
      // account page, or the client changed) — drop it so the UI stops
      // claiming a connection. A network hiccup must not do that.
      if (e.code == 'auth') await _clearSession(prefs);
      rethrow;
    }
    if (session == null) throw const GoogleAuthException('not_connected');
    await _storeSession(prefs, session);
    return session.accessToken;
  }

  /// Bearer headers for a Drive API call, so callers do not each repeat the
  /// token plumbing.
  static Future<Map<String, String>> authHeaders() async {
    return {'Authorization': 'Bearer ${await accessToken()}'};
  }

  static bool _cachedTokenIsUsable(SharedPreferences prefs) {
    final token = prefs.getString(_kAccessToken) ?? '';
    if (token.isEmpty) return false;
    final expiry = prefs.getInt(_kAccessExpiry) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(expiry).isAfter(DateTime.now().add(_skew));
  }

  static Future<void> _storeSession(SharedPreferences prefs, GoogleAuthSession session) async {
    await prefs.setString(_kAccessToken, session.accessToken);
    await prefs.setInt(_kAccessExpiry, session.expiresAt.millisecondsSinceEpoch);
    // Google normally does NOT rotate the refresh token on refresh, so an
    // absent one in the response means "keep the one you have", not "you no
    // longer have one" (same rule as drive.js's driveEnsureAccessToken).
    if (session.refreshToken != null) {
      await prefs.setString(_kRefreshToken, session.refreshToken!);
    }
  }

  static Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kAccessExpiry);
    await prefs.remove(_kEmail);
  }

  /// Best effort: a connection with no display name is still a working
  /// connection, so a failure here must not fail the login.
  static Future<String> _fetchEmail(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse(googleUserinfoEndpoint),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return '';
      return (jsonDecode(res.body) as Map<String, dynamic>)['email'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }
}
