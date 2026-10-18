import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataMode { localSqlite, demo }

/// Chrome is a UI demo target; Android uses the persistent local database.
final dataModeProvider = Provider<DataMode>(
  (ref) => kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? DataMode.demo
      : DataMode.localSqlite,
);
