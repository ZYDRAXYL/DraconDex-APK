import 'dart:async';

/// Neither dart:io nor JS interop: run [work] here.
Future<R> inBackground<R>(FutureOr<R> Function() work) async => work();
