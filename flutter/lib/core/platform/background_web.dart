import 'dart:async';

/// The web build has no isolate to hand [work] to: it runs here.
Future<R> inBackground<R>(FutureOr<R> Function() work) async => work();
