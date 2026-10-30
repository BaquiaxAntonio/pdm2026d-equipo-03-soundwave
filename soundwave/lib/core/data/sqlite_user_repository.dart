import '../contracts/user_repository.dart';
import '../database/user_dao.dart';
import '../models/app_user.dart';

class SqliteUserRepository implements UserRepository {
  const SqliteUserRepository(this.dao);
  final UserDao dao;
  @override
  Future<AppUser> register({required String username, String? displayName, required String password}) => dao.register(username: username, displayName: displayName, password: password);
  @override
  Future<AppUser?> signIn({required String username, required String password}) => dao.signIn(username: username, password: password);
  @override
  Future<AppUser?> findById(String id) => dao.findById(id);
  @override
  Future<List<AppUser>> all() => dao.all();
  @override
  Future<void> update(AppUser user, {String? password}) => dao.update(user, password: password);
  @override
  Future<void> delete(String id) async { await dao.delete(id); }
}
