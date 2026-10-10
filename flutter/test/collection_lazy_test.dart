import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/data/models/module_model.dart';
import 'package:dracondex/features/hub/widgets/module_collection_view.dart';
import 'package:dracondex/providers/builder_view_provider.dart';

/// Procress 19 F5: a folder's rows are slivers of the page's scroll view, so
/// a folder of 2,000 modules builds only the rows on screen — in every view
/// mode, and in the iOS grouped card (DdxGroupedSection.sliver).
void main() {
  const n = 2000;
  final modules = [
    for (var i = 0; i < n; i++)
      ModuleModel(
        id: i + 1,
        nexusRef: 1,
        name: 'M${'$i'.padLeft(4, '0')}',
        kind: ModuleKind.classifier,
        createdAt: '',
        updatedAt: '',
      ),
  ];

  for (final (mode, ios) in [
    (BuilderViewMode.list, false),
    (BuilderViewMode.list, true),
    (BuilderViewMode.compact, false),
    (BuilderViewMode.grid, false),
  ]) {
    testWidgets('${mode.name}${ios ? ' (iOS)' : ''} builds only what shows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theme = AppTheme.forName('midnight');
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: ios ? theme.copyWith(platform: TargetPlatform.iOS) : theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ModuleCollectionView(nexusId: 1, modules: modules, mode: mode, sliver: true),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('M0000'), findsOneWidget);
      expect(find.text('M1999'), findsNothing);
      final built = find.textContaining(RegExp(r'^M\d{4}$')).evaluate().length;
      expect(built, lessThan(60), reason: '$built of $n rows built');
    });
  }
}
