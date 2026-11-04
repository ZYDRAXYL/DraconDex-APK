import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One entry of a folder on the drive.
class SafEntry {
  final String name;
  final bool dir;
  final int size;

  /// Milliseconds since the epoch, as the document provider reports it.
  final int mtime;
  const SafEntry({required this.name, required this.dir, required this.size, required this.mtime});

  factory SafEntry.fromMap(Map<Object?, Object?> m) => SafEntry(
        name: '${m['name'] ?? ''}',
        dir: m['dir'] == true,
        size: (m['size'] as num?)?.toInt() ?? 0,
        mtime: (m['mtime'] as num?)?.toInt() ?? 0,
      );
}

/// Port Link on Android (APP Plan.md Procress 32 part 9.1) — the drive side
/// of a portable DraconDex, reached through the Storage Access Framework.
///
/// A USB-OTG stick or an SD card has no path an app may open: the user picks
/// the portable app's folder once ([pickTree]) and the app keeps a tree URI it
/// can come back to across restarts ([trees]). sqflite needs a real file, so a
/// vault or the drive's `app.ddx` is copied in to this app's own storage
/// ([copyIn]), used there, and the result copied back out ([copyOut] — a temp
/// beside the target, then renamed over it).
///
/// Paths are relative to the picked folder, `/`-separated
/// (`novel-manager-data/app.ddx`); a `..` segment is refused here before it
/// reaches native code. Everywhere but Android every call answers "nothing
/// there" instead of throwing — the same tree builds the PWA.
///
/// Native side: `android/app/src/main/kotlin/com/dracondex/app/SafChannel.kt`.
class Saf {
  static const channel = MethodChannel('dracondex/saf');

  /// Tests flip this; the app reads the platform.
  @visibleForTesting
  static bool? supportedOverride;
  static bool get supported => supportedOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static String _rel(String path) {
    final segs = path.split('/').where((s) => s.isNotEmpty && s != '.');
    if (segs.any((s) => s == '..')) throw ArgumentError.value(path, 'path', 'must stay inside the picked folder');
    return segs.join('/');
  }

  /// Opens the system folder picker. → the tree URI, or null when cancelled.
  static Future<String?> pickTree() async => supported ? channel.invokeMethod<String>('pickTree') : null;

  /// The folders this app was given and still has access to.
  static Future<List<String>> trees() async =>
      supported ? (await channel.invokeListMethod<String>('trees')) ?? const [] : const [];

  /// Gives a folder's access back ("forget this drive").
  static Future<void> release(String tree) async {
    if (supported) await channel.invokeMethod<bool>('release', {'tree': tree});
  }

  /// Is the drive plugged in, with this folder still on it?
  static Future<bool> available(String tree) async =>
      supported && (await channel.invokeMethod<bool>('available', {'tree': tree, 'path': ''}) ?? false);

  /// null when nothing is at [path].
  static Future<SafEntry?> stat(String tree, String path) async {
    if (!supported) return null;
    final m = await channel.invokeMapMethod<Object?, Object?>('stat', {'tree': tree, 'path': _rel(path)});
    return m == null ? null : SafEntry.fromMap({...m, 'name': _rel(path).split('/').last});
  }

  /// The entries of the folder at [path]; null when there is no such folder.
  static Future<List<SafEntry>?> list(String tree, String path) async {
    if (!supported) return null;
    final raw = await channel.invokeListMethod<Map<Object?, Object?>>('list', {'tree': tree, 'path': _rel(path)});
    return raw?.map(SafEntry.fromMap).toList();
  }

  /// Copies the drive file at [path] to the local file [dest].
  static Future<bool> copyIn(String tree, String path, String dest) async =>
      supported && (await channel.invokeMethod<bool>('copyIn', {'tree': tree, 'path': _rel(path), 'dest': dest}) ?? false);

  /// Copies the local file [src] to [path] on the drive (temp, then renamed over).
  static Future<bool> copyOut(String tree, String path, String src) async =>
      supported && (await channel.invokeMethod<bool>('copyOut', {'tree': tree, 'path': _rel(path), 'src': src}) ?? false);

  static Future<bool> mkdirs(String tree, String path) async =>
      supported && (await channel.invokeMethod<bool>('mkdirs', {'tree': tree, 'path': _rel(path)}) ?? false);

  static Future<bool> delete(String tree, String path) async =>
      supported && (await channel.invokeMethod<bool>('delete', {'tree': tree, 'path': _rel(path)}) ?? false);

  /// "Has this file changed since?" in the same form EXE's `port_link` keeps
  /// (`size:mtime`, src/db/portlink.js sigOf). null when there is no file.
  static String? sig(SafEntry? e) => e == null ? null : '${e.size}:${e.mtime}';
}
