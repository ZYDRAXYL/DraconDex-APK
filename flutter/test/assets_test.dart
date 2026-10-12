import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotoSans fonts declared in pubspec are bundled', () async {
    final manifest = json.decode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    final families = manifest
        .map((e) => (e as Map<String, dynamic>)['family'] as String)
        .toList();
    expect(families, contains('NotoSans'));

    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    expect(regular.lengthInBytes, greaterThan(0));
    expect(bold.lengthInBytes, greaterThan(0));
  });

  test('image assets are bundled', () async {
    final icon = await rootBundle.load('assets/images/DraconDex-IconApp.png');
    expect(icon.lengthInBytes, greaterThan(0));
    // The rail logo: the small WebP copies, not the 1.4 MB masters.
    for (final tone in ['White', 'Black']) {
      final logo = await rootBundle.load('assets/images/DraconDex-Symbol$tone.webp');
      expect(logo.lengthInBytes, inInclusiveRange(1, 64 * 1024));
    }
  });
}
