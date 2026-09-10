import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Shared vocabulary for the Google OAuth login, imported by both the
/// platform implementations (google_auth_platform_io/web.dart) and the
/// façade that stores their results (google_auth_service.dart). It lives in
/// its own file so the two sides can talk about the same types without the
/// platform files importing the façade that imports them back.

/// The app's own OAuth scopes — identical to the Electron app's DRIVE_SCOPE
/// in electron/src/db/drive.js, so one Google Cloud project (and one consent
/// screen) covers every build target. `drive.appdata` is a private per-app
/// folder: this app cannot see anything else in the user's Drive.
const googleOAuthScope = 'email https://www.googleapis.com/auth/drive.appdata';

const googleAuthEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
const googleTokenEndpoint = 'https://oauth2.googleapis.com/token';
const googleRevokeEndpoint = 'https://oauth2.googleapis.com/revoke';
const googleUserinfoEndpoint = 'https://www.googleapis.com/oauth2/v3/userinfo';

/// Every failure the login can produce, as a stable code rather than a raw
/// message — the UI maps these to localized strings the same way the
/// Supabase setup screen maps its own codes (see _codeMessage there), and
/// the same way electron/src/renderer/drive.js's driveErrToast does.
///
/// * `no_config`      — no client id (or, on native, no client secret) saved yet
/// * `cancelled`      — the user closed the browser tab / popup
/// * `login_timeout`  — the consent screen was never completed
/// * `state_mismatch` — the redirect did not echo our CSRF nonce back
/// * `network`        — the token or userinfo request never reached Google
/// * `auth`           — Google refused the code, the token, or the refresh
/// * `popup_blocked`  — web only: the browser blocked the consent popup
/// * `unsupported`    — a build target with neither dart:io nor a browser
class GoogleAuthException implements Exception {
  final String code;
  final String? detail;
  const GoogleAuthException(this.code, [this.detail]);

  @override
  String toString() => 'GoogleAuthException($code${detail == null ? '' : ': $detail'})';
}

/// What an interactive login (or a refresh) hands back.
///
/// [refreshToken] is null on web on purpose: a browser client uses the
/// implicit flow and Google never issues a refresh token to it, so the web
/// build re-authorizes when [expiresAt] passes instead of refreshing. Native
/// builds get one and behave like the Electron app — connect once, stay
/// connected. See docs/DRIVE.md §2.3b.
class GoogleAuthSession {
  final String accessToken;
  final DateTime expiresAt;
  final String? refreshToken;

  const GoogleAuthSession({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  factory GoogleAuthSession.fromTokenResponse(Map<String, dynamic> body) {
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    return GoogleAuthSession(
      accessToken: body['access_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      refreshToken: body['refresh_token'] as String?,
    );
  }
}

String _base64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// PKCE verifier/challenge pair — the same S256 shape as makePkcePair() in
/// electron/src/db/oauth-loopback.js.
class GooglePkcePair {
  final String verifier;
  final String challenge;
  const GooglePkcePair(this.verifier, this.challenge);

  factory GooglePkcePair.generate() {
    final verifier = _base64Url(_randomBytes(32));
    final challenge = _base64Url(sha256.convert(ascii.encode(verifier)).bytes);
    return GooglePkcePair(verifier, challenge);
  }
}

/// CSRF nonce for the authorize URL, checked when the redirect comes back.
String googleAuthState() => _randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _randomBytes(int n) {
  final rnd = Random.secure();
  return List<int>.generate(n, (_) => rnd.nextInt(256));
}

/// Builds Google's authorize URL. [responseType] is `code` for the native
/// authorization-code + PKCE flow and `token` for the browser's implicit
/// flow; the extra code-challenge parameters are only meaningful for the
/// former, so they are omitted for the latter.
String buildGoogleAuthUrl({
  required String clientId,
  required String redirectUri,
  required String state,
  required String responseType,
  String? codeChallenge,
  bool promptConsent = true,
}) {
  final params = <String, String>{
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': responseType,
    'scope': googleOAuthScope,
    'state': state,
    'include_granted_scopes': 'true',
    if (responseType == 'code') 'access_type': 'offline',
    // Without this Google only returns a refresh token on the very first
    // consent ever granted to the client, so a user who reinstalls (or
    // disconnects and reconnects) would come back with no way to refresh.
    if (responseType == 'code' && promptConsent) 'prompt': 'consent',
    if (codeChallenge != null) ...{
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    },
  };
  return Uri.parse(googleAuthEndpoint).replace(queryParameters: params).toString();
}
