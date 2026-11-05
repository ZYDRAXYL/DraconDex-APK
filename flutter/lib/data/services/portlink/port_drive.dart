import '../../../core/platform/saf.dart';

/// The drive side of a sync: the portable app's folder, paths relative to it
/// and `/`-separated. [SafDrive] on a phone; the tests use a plain folder.
abstract class PortDrive {
  /// What this app keeps to find the drive again (a tree URI on Android).
  String get id;
  Future<SafEntry?> stat(String rel);
  Future<List<SafEntry>?> list(String rel);
  Future<bool> copyIn(String rel, String dest);
  Future<bool> copyOut(String rel, String src);
  Future<bool> mkdirs(String rel);
  Future<bool> delete(String rel);
}

class SafDrive implements PortDrive {
  final String tree;
  const SafDrive(this.tree);
  @override
  String get id => tree;
  @override
  Future<SafEntry?> stat(String rel) => Saf.stat(tree, rel);
  @override
  Future<List<SafEntry>?> list(String rel) => Saf.list(tree, rel);
  @override
  Future<bool> copyIn(String rel, String dest) => Saf.copyIn(tree, rel, dest);
  @override
  Future<bool> copyOut(String rel, String src) => Saf.copyOut(tree, rel, src);
  @override
  Future<bool> mkdirs(String rel) => Saf.mkdirs(tree, rel);
  @override
  Future<bool> delete(String rel) => Saf.delete(tree, rel);
}

/// One Nexus the portable app has, from its `app.ddx`.
class DriveNexus {
  final int id;
  final String name;
  final String? memo;
  final String? color;

  /// Relative to the drive folder; null when the row points somewhere else.
  final String? fileRel, locateRel;
  final bool missing;
  const DriveNexus({required this.id, required this.name, this.memo, this.color, this.fileRel, this.locateRel, required this.missing});
}

/// A portable DraconDex as read off its folder. Every path in the portable
/// app's files is absolute, written against [ownRoot] — the folder it last
/// ran from (a Windows path, most of the time). [rel]/[abs] convert.
class DriveInfo {
  final String driveUid, dataDir, ownRoot;
  final List<DriveNexus> nexuses;
  const DriveInfo({required this.driveUid, required this.dataDir, required this.ownRoot, required this.nexuses});

  String get sep => ownRoot.contains(r'\') ? r'\' : '/';
  String get _root => ownRoot.replaceAll(RegExp(r'[\\/]+$'), '');

  String abs(String rel) => rel.isEmpty ? _root : '$_root$sep${rel.split('/').join(sep)}';

  String? rel(String? abs) {
    if (abs == null) return null;
    final win = sep == r'\';
    final a = win ? abs.toLowerCase() : abs, r = win ? _root.toLowerCase() : _root;
    if (a != r && !a.startsWith('$r$sep')) return null;
    final rest = abs.substring(_root.length).split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    return rest.contains('..') ? null : rest.join('/');
  }
}
