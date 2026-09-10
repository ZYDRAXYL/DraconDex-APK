import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/services/update_service.dart';

/// Checks once per provider lifetime (app boot, or a manual re-check via
/// `ref.invalidate`). Never throws — see UpdateService.checkForUpdate.
final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) {
  return UpdateService.checkForUpdate();
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});
