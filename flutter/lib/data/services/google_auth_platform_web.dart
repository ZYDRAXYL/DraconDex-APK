import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'google_auth_common.dart';

/// Web / PWA Google login.
///
/// A browser has no loopback socket to redirect to, and Google issues no
/// client secret (and therefore no refresh token) to a browser client, so
/// this is the implicit flow instead of the native file's code+PKCE one:
/// open the consent screen in a popup, let it come back to the app's own
/// `oauth-callback.html`, and read the access token out of the URL fragment
/// the popup posts back. The token is good for about an hour and there is
/// nothing to refresh with — GoogleAuthService treats an expired web token
/// as "not connected" and the user reconnects with one click (Google skips
/// the consent screen the second time, since the grant is already on file).
///
/// The user registers a **Web application** client for this, not the
/// "Desktop app" client the native build uses, because Google matches the
/// redirect URI exactly — googleAuthRedirectUriHint() returns the string to
/// paste into the client's "Authorized redirect URIs".
bool get googleAuthUsesRefreshToken => false;

const _loginTimeout = Duration(minutes: 5);

/// Prefix on the postMessage payload so an unrelated message (Flutter's own
/// web bootstrap posts a few) is never mistaken for an OAuth answer.
const _messagePrefix = 'dracondex-oauth:';

String? googleAuthRedirectUriHint() => _redirectUri();

/// A popup opened by [googleAuthPrepare], waiting for its real URL.
web.Window? _prepared;

/// Opens a blank popup *synchronously*, before any `await` runs.
///
/// This exists because a browser only allows `window.open` while it is still
/// handling the click that asked for it, and connect() has to read the saved
/// client id out of SharedPreferences first — an async gap that would make
/// the popup look unsolicited and get blocked. Opening `about:blank` up front
/// and pointing it at Google once the URL is ready is the standard way out;
/// the popup is same-origin until then, so setting its location is allowed.
void googleAuthPrepare() {
  _prepared = web.window.open('about:blank', 'dracondex_google_oauth', 'width=520,height=700');
}

/// Closes a prepared popup that never got used — an error between prepare and
/// authorize would otherwise leave a blank window sitting on the user's screen.
void googleAuthCancelPrepare() {
  _closeQuietly(_prepared);
  _prepared = null;
}

void _closeQuietly(web.Window? window) {
  try {
    window?.close();
  } catch (_) {
    // already gone
  }
}

/// Resolved against the `<base href>` Flutter stamps into index.html, so an
/// app served from a subdirectory (GitHub Pages serves this one from
/// `/<repo>/`) gets the redirect URI it is actually reachable at.
String _redirectUri() {
  final baseEl = web.document.querySelector('base') as web.HTMLBaseElement?;
  final href = baseEl?.href;
  final base = (href == null || href.isEmpty) ? Uri.base : Uri.parse(href);
  return base.resolve('oauth-callback.html').toString();
}

Future<GoogleAuthSession> googleAuthAuthorize({
  required String clientId,
  required String clientSecret,
}) {
  final state = googleAuthState();
  final url = buildGoogleAuthUrl(
    clientId: clientId,
    redirectUri: _redirectUri(),
    state: state,
    responseType: 'token',
  );

  // Normally the window googleAuthPrepare() opened during the click; the
  // direct open is only a fallback for a caller that did not prepare one,
  // and is the path most likely to be blocked.
  final popup = _prepared ?? web.window.open(url, 'dracondex_google_oauth', 'width=520,height=700');
  if (popup == null) {
    _prepared = null;
    throw const GoogleAuthException('popup_blocked');
  }
  if (_prepared != null) {
    _prepared = null;
    popup.location.href = url;
  }

  final completer = Completer<GoogleAuthSession>();
  Timer? closedPoll;
  late final JSFunction listener;

  void finish(void Function() complete, {bool closePopup = false}) {
    if (completer.isCompleted) return;
    closedPoll?.cancel();
    web.window.removeEventListener('message', listener);
    // On every path except a clean success the callback page has not closed
    // itself, so the popup would be left stranded on an error URL.
    if (closePopup) _closeQuietly(popup);
    complete();
  }

  void onMessage(web.MessageEvent event) {
    // Same-origin only: oauth-callback.html is served by this app, so a
    // message from anywhere else is not our redirect.
    if (event.origin != web.window.location.origin) return;
    final data = event.data.dartify();
    if (data is! String || !data.startsWith(_messagePrefix)) return;

    final params = _splitPayload(data.substring(_messagePrefix.length));
    if (params['state'] != state) {
      finish(() => completer.completeError(const GoogleAuthException('state_mismatch')), closePopup: true);
      return;
    }
    final error = params['error'];
    if (error != null) {
      finish(() => completer.completeError(
            GoogleAuthException(error == 'access_denied' ? 'cancelled' : 'auth', error),
          ), closePopup: true);
      return;
    }
    final token = params['access_token'];
    if (token == null || token.isEmpty) {
      finish(() => completer.completeError(const GoogleAuthException('auth', 'no_access_token')), closePopup: true);
      return;
    }
    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 3600;
    finish(() => completer.complete(GoogleAuthSession(
          accessToken: token,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        )));
  }

  listener = onMessage.toJS;
  web.window.addEventListener('message', listener);

  // The callback page posts its payload and then closes itself, so "closed"
  // alone does not mean cancelled — give the queued message a moment to
  // arrive before calling it off.
  closedPoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
    if (!popup.closed) return;
    closedPoll?.cancel();
    Timer(const Duration(milliseconds: 600), () {
      finish(() => completer.completeError(const GoogleAuthException('cancelled')));
    });
  });

  return completer.future.timeout(_loginTimeout, onTimeout: () {
    finish(() {}, closePopup: true);
    throw const GoogleAuthException('login_timeout');
  });
}

/// The payload is whatever followed `#` (or `?` on an error redirect) — both
/// are `application/x-www-form-urlencoded`.
Map<String, String> _splitPayload(String payload) {
  try {
    return Uri.splitQueryString(payload);
  } catch (_) {
    return const {};
  }
}

/// Nothing to refresh with in a browser — the caller re-authorizes instead.
Future<GoogleAuthSession?> googleAuthRefresh({
  required String clientId,
  required String clientSecret,
  required String refreshToken,
}) async => null;

/// Google's revoke endpoint sends no CORS headers, so a browser cannot call
/// it. Dropping the stored token is the whole disconnect here; the grant
/// stays on the user's Google account page until they remove it there.
Future<void> googleAuthRevoke(String token) async {}
