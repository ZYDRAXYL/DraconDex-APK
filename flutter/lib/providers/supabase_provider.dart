import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/supabase_setup_service.dart';

/// The stored Supabase project URL (empty when none), used to label the setup
/// tile in Settings. Re-read via `ref.invalidate` after the setup sheet saves
/// or clears — same pattern as googleConnectionProvider.
final supabaseUrlProvider = FutureProvider<String>((ref) {
  return SupabaseSetupService.loadUrl();
});
