import 'package:url_launcher/url_launcher.dart';

/// Whether [s] is a web address this app will hand to the browser: http or
/// https with a host — never file:, javascript:, data:, intent: or a custom
/// scheme another app registered (the desktop's block:openUrl rule, EXE
/// db/page-block.js blockLinkUrl).
bool isSafeWebUrl(String? s) {
  final u = Uri.tryParse((s ?? '').trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}

/// Opens [s] in the browser when [isSafeWebUrl] allows it; → false when it
/// does not, or nothing could open it. Every link that comes from vault data
/// (a URL field, a URL asset, a page link) goes through here.
Future<bool> safeLaunch(String? s) async {
  if (!isSafeWebUrl(s)) return false;
  return launchUrl(Uri.parse(s!.trim()), mode: LaunchMode.externalApplication);
}
