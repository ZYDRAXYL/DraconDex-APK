import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/author_model.dart';
import '../data/models/chronicler_model.dart';
import '../data/models/classifier_model.dart';
import '../data/models/designer_model.dart';
import '../data/models/locator_model.dart';
import '../data/models/narrator_model.dart';
import '../data/models/sketcher_model.dart';
import '../data/models/viewer_model.dart';
import '../data/models/wanderer_model.dart';
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

/// The module's timeline row, created on first open. Keyed by module id.
final timelineProvider = FutureProvider.family<int?, int>((ref, moduleId) async {
  final dao = ref.watch(chroniclerDaoProvider);
  return dao.when(
    data: (d) => d.ensureTimeline(moduleId),
    loading: () => Future<int?>.value(null),
    error: (e, s) => Future<int?>.error(e, s),
  );
});

final timelineEventsProvider =
    FutureProvider.family<List<TimelineEventModel>, int>((ref, timelineId) async {
  final dao = ref.watch(chroniclerDaoProvider);
  return dao.when(
    data: (d) => d.getEvents(timelineId),
    loading: () => Future.value(<TimelineEventModel>[]),
    error: (e, s) => Future<List<TimelineEventModel>>.error(e, s),
  );
});

final classifierFieldsProvider =
    FutureProvider.family<List<ClassifierFieldModel>, int>((ref, moduleId) async {
  final dao = ref.watch(classifierDaoProvider);
  return dao.when(
    data: (d) => d.getFields(moduleId),
    loading: () => Future.value(<ClassifierFieldModel>[]),
    error: (e, s) => Future<List<ClassifierFieldModel>>.error(e, s),
  );
});

final classifierItemsProvider =
    FutureProvider.family<List<ClassifierItemModel>, int>((ref, moduleId) async {
  final dao = ref.watch(classifierDaoProvider);
  return dao.when(
    data: (d) => d.getItems(moduleId),
    loading: () => Future.value(<ClassifierItemModel>[]),
    error: (e, s) => Future<List<ClassifierItemModel>>.error(e, s),
  );
});

/// The values one item holds, keyed by field id. A missing key means the
/// field was never filled in, which is not the same as an empty string.
final classifierValuesProvider =
    FutureProvider.family<Map<int, String?>, int>((ref, objectId) async {
  final dao = ref.watch(classifierDaoProvider);
  return dao.when(
    data: (d) => d.getValues(objectId),
    loading: () => Future.value(<int, String?>{}),
    error: (e, s) => Future<Map<int, String?>>.error(e, s),
  );
});

final dialoguesProvider =
    FutureProvider.family<List<DialogueModel>, int>((ref, moduleId) async {
  final dao = ref.watch(narratorDaoProvider);
  return dao.when(
    data: (d) => d.getDialogues(moduleId),
    loading: () => Future.value(<DialogueModel>[]),
    error: (e, s) => Future<List<DialogueModel>>.error(e, s),
  );
});

final talksProvider = FutureProvider.family<List<TalkModel>, int>((ref, dialogueId) async {
  final dao = ref.watch(narratorDaoProvider);
  return dao.when(
    data: (d) => d.getTalks(dialogueId),
    loading: () => Future.value(<TalkModel>[]),
    error: (e, s) => Future<List<TalkModel>>.error(e, s),
  );
});

final storyEdgesProvider =
    FutureProvider.family<List<StoryEdgeModel>, int>((ref, dialogueId) async {
  final dao = ref.watch(narratorDaoProvider);
  return dao.when(
    data: (d) => d.getEdgesFrom(dialogueId),
    loading: () => Future.value(<StoryEdgeModel>[]),
    error: (e, s) => Future<List<StoryEdgeModel>>.error(e, s),
  );
});

/// The vault-wide item index, keyed by Nexus. Shared by Viewer and Connector
/// — both filter the same index, so they share the cache entry too.
final viewerIndexProvider =
    FutureProvider.family<List<IndexedItem>, int>((ref, nexusId) async {
  final dao = ref.watch(viewerDaoProvider);
  return dao.when(
    data: (d) => d.index(nexusId),
    loading: () => Future.value(<IndexedItem>[]),
    error: (e, s) => Future<List<IndexedItem>>.error(e, s),
  );
});

/// The module's saved filter, keyed by module id.
final filterDefProvider = FutureProvider.family<FilterDef, int>((ref, moduleId) async {
  final dao = ref.watch(viewerDaoProvider);
  return dao.when(
    data: (d) => d.getFilterDef(moduleId),
    loading: () => Future.value(const FilterDef()),
    error: (e, s) => Future<FilterDef>.error(e, s),
  );
});

final relationsProvider =
    FutureProvider.family<List<Map<String, Object?>>, int>((ref, nexusId) async {
  final dao = ref.watch(viewerDaoProvider);
  return dao.when(
    data: (d) => d.getRelations(nexusId),
    loading: () => Future.value(<Map<String, Object?>>[]),
    error: (e, s) => Future<List<Map<String, Object?>>>.error(e, s),
  );
});

final designNodesProvider =
    FutureProvider.family<List<DesignNodeModel>, int>((ref, moduleId) async {
  final dao = ref.watch(designerDaoProvider);
  return dao.when(
    data: (d) => d.getNodes(moduleId),
    loading: () => Future.value(<DesignNodeModel>[]),
    error: (e, s) => Future<List<DesignNodeModel>>.error(e, s),
  );
});

final designEdgesProvider =
    FutureProvider.family<List<DesignEdgeModel>, int>((ref, moduleId) async {
  final dao = ref.watch(designerDaoProvider);
  return dao.when(
    data: (d) => d.getEdges(moduleId),
    loading: () => Future.value(<DesignEdgeModel>[]),
    error: (e, s) => Future<List<DesignEdgeModel>>.error(e, s),
  );
});

final sketchPagesProvider =
    FutureProvider.family<List<SketchPageModel>, int>((ref, moduleId) async {
  final dao = ref.watch(sketcherDaoProvider);
  return dao.when(
    data: (d) => d.getPages(moduleId),
    loading: () => Future.value(<SketchPageModel>[]),
    error: (e, s) => Future<List<SketchPageModel>>.error(e, s),
  );
});

final sketchStrokesProvider =
    FutureProvider.family<List<SketchStrokeModel>, int>((ref, pageId) async {
  final dao = ref.watch(sketcherDaoProvider);
  return dao.when(
    data: (d) => d.getStrokes(pageId),
    loading: () => Future.value(<SketchStrokeModel>[]),
    error: (e, s) => Future<List<SketchStrokeModel>>.error(e, s),
  );
});

/// The module's map row, created on first open. Keyed by module id.
final moduleMapProvider = FutureProvider.family<MapModel?, int>((ref, moduleId) async {
  final dao = ref.watch(locatorDaoProvider);
  return dao.when(
    data: (d) => d.ensureMap(moduleId),
    loading: () => Future<MapModel?>.value(null),
    error: (e, s) => Future<MapModel?>.error(e, s),
  );
});

final mapAreasProvider = FutureProvider.family<List<MapAreaModel>, int>((ref, mapId) async {
  final dao = ref.watch(locatorDaoProvider);
  return dao.when(
    data: (d) => d.getAreas(mapId),
    loading: () => Future.value(<MapAreaModel>[]),
    error: (e, s) => Future<List<MapAreaModel>>.error(e, s),
  );
});

final mapPinsProvider = FutureProvider.family<List<MapEventModel>, int>((ref, moduleId) async {
  final dao = ref.watch(wandererDaoProvider);
  return dao.when(
    data: (d) => d.getPins(moduleId),
    loading: () => Future.value(<MapEventModel>[]),
    error: (e, s) => Future<List<MapEventModel>>.error(e, s),
  );
});

/// Timeline events across the Nexus, for the Wanderer's link picker.
final linkableEventsProvider =
    FutureProvider.family<List<LinkableEvent>, int>((ref, nexusId) async {
  final dao = ref.watch(wandererDaoProvider);
  return dao.when(
    data: (d) => d.listNexusEvents(nexusId),
    loading: () => Future.value(<LinkableEvent>[]),
    error: (e, s) => Future<List<LinkableEvent>>.error(e, s),
  );
});
