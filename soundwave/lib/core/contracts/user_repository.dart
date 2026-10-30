import '../models/app_user.dart';

abstract interface class UserRepository {
  Future<AppUser> register({required String username, String? displayName, required String password});
  Future<AppUser?> signIn({required String username, required String password});
  Future<AppUser?> findById(String id);
  Future<List<AppUser>> all();
  Future<void> update(AppUser user, {String? password});
  Future<void> delete(String id);
}
