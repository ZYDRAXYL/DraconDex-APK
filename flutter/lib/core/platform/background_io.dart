import 'dart:async';
import 'dart:isolate';

/// [work] on a short-lived isolate. What it captures is copied there; what it
/// returns comes back without a copy (Isolate.exit). Keep [work] a closure
/// over plain data — a String, bytes, a decoded JSON map — never over a
/// Database or a widget.
Future<R> inBackground<R>(FutureOr<R> Function() work) => Isolate.run(work);
