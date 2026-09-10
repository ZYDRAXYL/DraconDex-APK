import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/hashtag_model.dart';
import 'db_providers.dart';

final hashtagsProvider = FutureProvider<List<HashtagModel>>((ref) async {
  final dao = ref.watch(hashtagDaoProvider);
  return dao.when(
    data: (d) => d.getHashtags(),
    loading: () => Future.value([]),
    error: (e, s) => Future.value([]),
  );
});
