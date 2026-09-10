/// The half of the Google login that cannot be written once for every build
/// target: how the consent screen is opened and how its answer comes back.
///
/// * native (`dart:io`) — the Electron app's exact flow: a throwaway loopback
///   HTTP server, the system browser, authorization code + PKCE, refresh token.
/// * web — no loopback socket exists in a browser, so a popup returns an
///   access token directly (implicit flow) and there is no refresh token.
///
/// Conditional export rather than a `kIsWeb` branch because `dart:io` is a
/// *compile-time* error on the web target — see docs/PWA.md §3.
library;

export 'google_auth_platform_stub.dart'
    if (dart.library.io) 'google_auth_platform_io.dart'
    if (dart.library.js_interop) 'google_auth_platform_web.dart';
