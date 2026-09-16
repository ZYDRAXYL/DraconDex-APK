import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../data/dao/author_dao.dart';
import '../data/dao/chronicler_dao.dart';
import '../data/dao/color_dao.dart';
import '../data/dao/hashtag_dao.dart';
import '../data/dao/module_dao.dart';
import '../data/dao/scribe_dao.dart';

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
