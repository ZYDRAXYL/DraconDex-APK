import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/google_auth_service.dart';

/// The Google account the app is connected to, if any. Re-read once per
/// provider lifetime (app boot) or via `ref.invalidate` after connect /
/// disconnect / a saved client id — same pattern as updateCheckProvider.
final googleConnectionProvider = FutureProvider<GoogleConnection>((ref) {
  return GoogleAuthService.connection();
});

/// Whether an OAuth client has been entered at all. Separate from the
/// connection because the UI has three states to draw, not two: no client
/// yet (go set one up), a client but no grant (connect), and connected.
final googleConfigProvider = FutureProvider<GoogleAuthConfig>((ref) {
  return GoogleAuthService.loadConfig();
});
