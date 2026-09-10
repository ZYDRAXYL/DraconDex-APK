import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/color_model.dart';
import 'db_providers.dart';

final colorsProvider = FutureProvider<List<ColorModel>>((ref) async {
  final dao = ref.watch(colorDaoProvider);
  return dao.when(
    data: (d) => d.getColors(),
    loading: () => Future.value([]),
    error: (e, s) => Future.value([]),
  );
});

final recentColorsProvider = FutureProvider<List<ColorModel>>((ref) async {
  final dao = ref.watch(colorDaoProvider);
  return dao.when(
    data: (d) => d.getRecentColors(),
    loading: () => Future.value([]),
    error: (e, s) => Future.value([]),
  );
});
