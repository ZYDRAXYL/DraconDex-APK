import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'google_auth_common.dart';

/// Native (Android / iOS / desktop) Google login.
///
/// This is a deliberate port of electron/src/db/drive.js + oauth-loopback.js
/// rather than a plugin call: the previous implementation used
/// `google_sign_in`, whose Android half only works when an *Android* OAuth
/// client carrying this app's package name and the signing certificate's
/// SHA-1 is registered in a Google Cloud project — which the person building
/// or forking this app has to own, and which fails at runtime with
/// ApiException 10 (DEVELOPER_ERROR) until they do. A "Desktop app" client
/// has no fingerprint to register, so the same client id/secret a user
/// already created for the Electron app works here unchanged, and the flow
/// below is the whole dependency: a loopback socket, the system browser, and
/// two plain HTTPS calls.
bool get googleAuthUsesRefreshToken => true;

/// Native redirects go to a loopback port picked fresh for every login, so
/// there is no fixed URI for the user to register (Google exempts
/// `http://127.0.0.1:<any port>` for installed-app clients).
String? googleAuthRedirectUriHint() => null;

const _loginTimeout = Duration(minutes: 5);
const _httpTimeout = Duration(seconds: 20);

/// No-ops here: the native flow hands the consent screen to the system
/// browser, which needs no gesture-time window to be reserved for it.
void googleAuthPrepare() {}

void googleAuthCancelPrepare() {}

Future<GoogleAuthSession> googleAuthAuthorize({
  required String clientId,
  required String clientSecret,
}) async {
  final pkce = GooglePkcePair.generate();
  final state = googleAuthState();

  // Port 0 = let the OS pick a free one. Bound before the browser opens so
  // the redirect can never arrive at a port nothing is listening on.
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirectUri = 'http://127.0.0.1:${server.port}/callback';

  String code;
  try {
    final url = Uri.parse(buildGoogleAuthUrl(
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
      responseType: 'code',
      codeChallenge: pkce.challenge,
    ));
    // externalApplication, never an in-app webview: Google refuses OAuth in
    // embedded webviews (disallowed_useragent), and a Custom Tab also lets
    // the user see the real accounts.google.com address bar.
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw const GoogleAuthException('cancelled', 'no browser available');
    }
    code = await _awaitCode(server, state);
  } finally {
    // force: the browser may still be holding the connection open on the
    // success page; without this the port would linger until it times out.
    await server.close(force: true);
  }

  return _exchange({
    'grant_type': 'authorization_code',
    'code': code,
    'client_id': clientId,
    'client_secret': clientSecret,
    'redirect_uri': redirectUri,
    'code_verifier': pkce.verifier,
  });
}

/// Waits for the one redirect we care about. Any other path is answered 404
/// and ignored rather than ending the wait — a stray probe on the port must
/// not cancel a login the user is still completing in the browser.
Future<String> _awaitCode(HttpServer server, String state) {
  final completer = Completer<String>();
  late final StreamSubscription<HttpRequest> sub;

  void finish(void Function() complete) {
    if (completer.isCompleted) return;
    complete();
    sub.cancel();
  }

  sub = server.listen((request) async {
    if (request.uri.path != '/callback') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final params = request.uri.queryParameters;

    // Checked before anything else is read off the URL and before the success
    // page is served, so a redirect we cannot verify never looks like it
    // worked to the person watching the browser. Same reasoning as the
    // state check in electron/src/db/oauth-loopback.js.
    if (params['state'] != state) {
      await _reply(request, 'Login failed — the request could not be verified. You can close this tab.');
      finish(() => completer.completeError(const GoogleAuthException('state_mismatch')));
      return;
    }
    final error = params['error'];
    if (error != null) {
      await _reply(request, 'Login cancelled. You can close this tab.');
      finish(() => completer.completeError(
            GoogleAuthException(error == 'access_denied' ? 'cancelled' : 'auth', error),
          ));
      return;
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      await _reply(request, 'Login failed — no authorization code. You can close this tab.');
      finish(() => completer.completeError(const GoogleAuthException('auth', 'no_code')));
      return;
    }
    await _reply(request, 'DraconDex is connected to Google Drive. You can close this tab.');
    finish(() => completer.complete(code));
  }, onError: (Object e) {
    finish(() => completer.completeError(GoogleAuthException('network', '$e')));
  });

  return completer.future.timeout(_loginTimeout, onTimeout: () {
    sub.cancel();
    throw const GoogleAuthException('login_timeout');
  });
}

Future<void> _reply(HttpRequest request, String message) async {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.html
    ..write('<!doctype html><html><head><meta charset="utf-8">'
        '<title>DraconDex</title></head>'
        '<body style="font-family:sans-serif;padding:2rem">$message</body></html>');
  await request.response.close();
}

Future<GoogleAuthSession?> googleAuthRefresh({
  required String clientId,
  required String clientSecret,
  required String refreshToken,
}) {
  return _exchange({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': clientId,
    'client_secret': clientSecret,
  });
}

Future<GoogleAuthSession> _exchange(Map<String, String> body) async {
  http.Response res;
  try {
    res = await http
        .post(
          Uri.parse(googleTokenEndpoint),
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        )
        .timeout(_httpTimeout);
  } catch (e) {
    throw GoogleAuthException('network', '$e');
  }
  if (res.statusCode != 200) {
    final detail = _errorDetail(res.body) ?? 'HTTP ${res.statusCode}';
    throw GoogleAuthException('auth', detail);
  }
  return GoogleAuthSession.fromTokenResponse(jsonDecode(res.body) as Map<String, dynamic>);
}

String? _errorDetail(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['error_description'] ?? json['error']) as String?;
  } catch (_) {
    return null;
  }
}

/// Best effort — the local token is dropped either way, so a revoke that
/// never reaches Google must not make "disconnect" look like it failed.
Future<void> googleAuthRevoke(String token) async {
  try {
    await http.post(Uri.parse('$googleRevokeEndpoint?token=${Uri.encodeComponent(token)}'))
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // ignored on purpose
  }
}
