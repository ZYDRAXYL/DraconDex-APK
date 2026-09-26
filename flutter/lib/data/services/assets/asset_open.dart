// Opening a Nest file in another app (Procress 14, APP docs/MEDIA-EMBED.md
// on the phone): the phone draws a poster and hands the file to whatever
// plays videos, reads PDFs or views 3D models there. On Android/iOS that is
// the stored copy through the system's "open with"; the web build has no
// file to point at, so there the bytes go through the share sheet.
export 'asset_open_stub.dart' if (dart.library.io) 'asset_open_io.dart';
