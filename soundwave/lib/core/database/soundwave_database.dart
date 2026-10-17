import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

final soundwaveDatabaseProvider = FutureProvider<Database>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError(
      'SQLite is configured for Android. Use demo repositories on other '
      'targets.',
    );
  }

  final appDirectory = await getApplicationSupportDirectory();
  final database = await openDatabase(
    path.join(appDirectory.path, databaseName),
    version: databaseVersion,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) => createDatabaseSchema(db),
    onUpgrade: upgradeDatabaseSchema,
  );
  ref.onDispose(() => unawaited(database.close()));
  return database;
});
