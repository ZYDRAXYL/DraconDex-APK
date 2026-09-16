import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/author_model.dart';
import '../data/models/scribe_model.dart';
import 'db_providers.dart';

/// Content providers for the kind-specific module editors. Each is keyed by
/// the owning module (or session) id, and each propagates a DAO failure the
/// way module_provider.dart does — an empty list and a broken database must
/// not look the same on screen.

final chaptersProvider = FutureProvider.family<List<ChapterModel>, int>((ref, moduleId) async {
  final dao = ref.watch(authorDaoProvider);
  return dao.when(
    data: (d) => d.getChapters(moduleId),
    loading: () => Future.value(<ChapterModel>[]),
    error: (e, s) => Future<List<ChapterModel>>.error(e, s),
  );
});

final chatSessionsProvider = FutureProvider.family<List<ChatSessionModel>, int>((ref, moduleId) async {
  final dao = ref.watch(scribeDaoProvider);
  return dao.when(
    data: (d) => d.getSessions(moduleId),
    loading: () => Future.value(<ChatSessionModel>[]),
    error: (e, s) => Future<List<ChatSessionModel>>.error(e, s),
  );
});

final chatMessagesProvider = FutureProvider.family<List<ChatMessageModel>, int>((ref, sessionId) async {
  final dao = ref.watch(scribeDaoProvider);
  return dao.when(
    data: (d) => d.getMessages(sessionId),
    loading: () => Future.value(<ChatMessageModel>[]),
    error: (e, s) => Future<List<ChatMessageModel>>.error(e, s),
  );
});
