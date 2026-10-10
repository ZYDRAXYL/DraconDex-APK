import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/widgets/sized_image.dart';

/// Procress 19 part 3: a picture is decoded at the size it is drawn, not the
/// size of the file.
void main() {
  final bytes = Uint8List.fromList(const [0, 1, 2, 3]);

  Future<ResizeImage> pumpIn(WidgetTester tester, Widget image, {double w = 100, double h = 50}) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: w, height: h, child: image)),
    ));
    return tester.widget<Image>(find.byType(Image)).image as ResizeImage;
  }

  testWidgets('the box width, in device pixels, in steps of 64', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    final r = await pumpIn(tester, SizedImage(bytes, fit: BoxFit.contain));
    expect(r.width, ((100 * dpr) / 64).ceil() * 64);
    expect(r.height, isNull, reason: 'only the width: the aspect ratio stays');
  });

  testWidgets('cover leaves room for a picture twice as wide as tall', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    final r = await pumpIn(tester, SizedImage(bytes, fit: BoxFit.cover), w: 48, h: 48);
    expect(r.width, ((96 * dpr) / 64).ceil() * 64);
  });

  testWidgets('a given width wins over the box', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    final r = await pumpIn(tester, SizedImage(bytes, fit: BoxFit.contain, width: 40, height: 40), w: 300);
    expect(r.width, ((40 * dpr) / 64).ceil() * 64);
  });
}
