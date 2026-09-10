// dart:io's Platform is unavailable at compile time on web — conditional
// export keeps it out of the web build's compile graph entirely (a runtime
// kIsWeb guard around Platform.isAndroid would still fail to compile).
export 'platform_check_stub.dart' if (dart.library.io) 'platform_check_io.dart';
