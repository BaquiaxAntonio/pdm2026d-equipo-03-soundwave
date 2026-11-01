import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sqlite_user_repository.dart';
import '../database/dao_providers.dart';
import '../contracts/user_repository.dart';

final userRepositoryProvider = FutureProvider<UserRepository>(
  (ref) async => SqliteUserRepository(await ref.watch(userDaoProvider.future)),
);
