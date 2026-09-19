import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../data/dao/author_dao.dart';
import '../data/dao/chronicler_dao.dart';
import '../data/dao/classifier_dao.dart';
import '../data/dao/color_dao.dart';
import '../data/dao/designer_dao.dart';
import '../data/dao/hashtag_dao.dart';
import '../data/dao/locator_dao.dart';
import '../data/dao/module_dao.dart';
import '../data/dao/narrator_dao.dart';
import '../data/dao/scribe_dao.dart';
import '../data/dao/sketcher_dao.dart';
import '../data/dao/viewer_dao.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseHelper.instance.database;
});

final colorDaoProvider = Provider<AsyncValue<ColorDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ColorDao(db));
});

final hashtagDaoProvider = Provider<AsyncValue<HashtagDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => HashtagDao(db));
});

final moduleDaoProvider = Provider<AsyncValue<ModuleDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ModuleDao(db));
});

final authorDaoProvider = Provider<AsyncValue<AuthorDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => AuthorDao(db));
});

final scribeDaoProvider = Provider<AsyncValue<ScribeDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ScribeDao(db));
});

final chroniclerDaoProvider = Provider<AsyncValue<ChroniclerDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ChroniclerDao(db));
});

final classifierDaoProvider = Provider<AsyncValue<ClassifierDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ClassifierDao(db));
});

final narratorDaoProvider = Provider<AsyncValue<NarratorDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => NarratorDao(db));
});

final viewerDaoProvider = Provider<AsyncValue<ViewerDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => ViewerDao(db));
});

final designerDaoProvider = Provider<AsyncValue<DesignerDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => DesignerDao(db));
});

final sketcherDaoProvider = Provider<AsyncValue<SketcherDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => SketcherDao(db));
});

final locatorDaoProvider = Provider<AsyncValue<LocatorDao>>((ref) {
  return ref.watch(databaseProvider).whenData((db) => LocatorDao(db));
});
