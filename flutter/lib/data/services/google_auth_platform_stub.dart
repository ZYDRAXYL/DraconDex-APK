import 'google_auth_common.dart';

/// Fallback for a target with neither `dart:io` nor a browser. Nothing ships
/// on such a target today; this exists so the conditional export in
/// google_auth_platform.dart has a default branch that still type-checks.
bool get googleAuthUsesRefreshToken => false;

String? googleAuthRedirectUriHint() => null;

/// No-ops — see google_auth_platform_web.dart for what these are for.
void googleAuthPrepare() {}

void googleAuthCancelPrepare() {}

Future<GoogleAuthSession> googleAuthAuthorize({
  required String clientId,
  required String clientSecret,
}) async => throw const GoogleAuthException('unsupported');

Future<GoogleAuthSession?> googleAuthRefresh({
  required String clientId,
  required String clientSecret,
  required String refreshToken,
}) async => throw const GoogleAuthException('unsupported');

Future<void> googleAuthRevoke(String token) async {}
