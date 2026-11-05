const portlinkFilesSupported = false;

Never _no() => throw UnsupportedError('Port Link needs a filesystem');
Future<String> plTempDir() async => _no();
Future<String> plBaseDir() async => _no();
Future<String> plAssetDir(int nexusId) async => _no();
Future<void> plCopy(String from, String to) async => _no();
Future<bool> plExists(String path) async => false;
Future<String> plRead(String path) async => _no();
Future<void> plDelete(String path) async {}
Future<void> plEnsureParent(String path) async => _no();
