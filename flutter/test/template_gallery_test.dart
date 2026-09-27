import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/features/page/template_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SizedBox(width: 360, child: child)),
      );

  const blocks = [
    {'component': 'classifier.spotlight'},
    {
      'type': 'columns',
      'children': [
        [
          {'type': 'text'},
        ],
        [
          {'component': 'classifier.breakdown'},
        ],
      ],
    },
  ];

  testWidgets('the preview names each block by its component label, columns side by side', (tester) async {
    await tester.pumpWidget(host(const TemplateBlocks(blocks: blocks)));
    expect(find.text('Spotlight'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Breakdown'), findsOneWidget);
    // the two columns share a row
    expect(tester.getTopLeft(find.text('Text')).dy, tester.getTopLeft(find.text('Breakdown')).dy);
  });

  testWidgets('the thumbnail draws without overflowing for a long page', (tester) async {
    await tester.pumpWidget(host(TemplateThumb(blocks: [for (var i = 0; i < 12; i++) ...blocks])));
    expect(tester.takeException(), isNull);
  });
}
