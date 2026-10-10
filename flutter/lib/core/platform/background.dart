// Runs CPU work (decoding a 600 KB snapshot, gzip, hashing a .dxpack's files)
// off the UI isolate on a native build, so a frame is not held up for it
// (Procress 19 part 4). The web build has no isolates to hand work to —
// dart:isolate's Isolate.run does not exist there — so it runs the work in
// place, as before. Conditional export keeps dart:isolate out of the web
// build's compile graph, the same pattern as db_factory.dart.
export 'background_stub.dart' if (dart.library.io) 'background_io.dart' if (dart.library.js_interop) 'background_web.dart';
