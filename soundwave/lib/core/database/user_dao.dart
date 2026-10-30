import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';

class UserDao {
  UserDao(this.database);
  final Database database;
  static const _iterations = 120000;

  Future<AppUser> register({required String username, String? displayName, required String password}) async {
    final name = username.trim();
    _validate(name, password);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final encoded = _encodeHash(password, salt);
    await database.insert('users', {'id': id, 'username': name, 'display_name': _clean(displayName), 'password_hash': encoded});
    return AppUser(id: id, username: name, displayName: _clean(displayName));
  }

  Future<AppUser?> signIn({required String username, required String password}) async {
    final rows = await database.query('users', where: 'username = ?', whereArgs: [username.trim()], limit: 1);
    if (rows.isEmpty) return null;
    final encoded = rows.first['password_hash']! as String;
    final parts = encoded.split(r'$');
    if (parts.length != 3 || int.tryParse(parts[0]) == null) return null;
    final salt = base64Url.decode(base64Url.normalize(parts[1]));
    final expected = base64Url.decode(base64Url.normalize(parts[2]));
    final actual = _derive(password, salt, int.parse(parts[0]));
    if (!_constantTimeEquals(actual, expected)) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findById(String id) async {
    final rows = await database.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> all() async => (await database.query('users', orderBy: 'username COLLATE NOCASE')).map(AppUser.fromMap).toList(growable: false);

  Future<void> update(AppUser user, {String? password}) async {
    if (user.username.trim().isEmpty) throw ArgumentError.value(user.username, 'username');
    final values = <String, Object?>{'username': user.username.trim(), 'display_name': _clean(user.displayName)};
    if (password != null) {
      if (password.length < 8) throw ArgumentError.value(password, 'password', 'Must be at least 8 characters.');
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      values['password_hash'] = _encodeHash(password, salt);
    }
    await database.update('users', values, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> delete(String id) async { await database.delete('users', where: 'id = ?', whereArgs: [id]); }

  void _validate(String username, String password) {
    if (username.isEmpty) throw ArgumentError.value(username, 'username', 'Required.');
    if (password.length < 8) throw ArgumentError.value(password, 'password', 'Must be at least 8 characters.');
  }

  String _encodeHash(String password, List<int> salt) => '$_iterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(_derive(password, salt, _iterations))}';
  List<int> _derive(String password, List<int> salt, int rounds) {
    final input = utf8.encode(password);
    var u = sha256.convert([...salt, ...input]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < rounds; i++) {
      u = sha256.convert([...u, ...salt, ...input]).bytes;
      for (var j = 0; j < result.length; j++) { result[j] ^= u[j]; }
    }
    return result;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) { difference |= a[i] ^ b[i]; }
    return difference == 0;
  }

  String? _clean(String? value) { final result = value?.trim(); return result == null || result.isEmpty ? null : result; }
}
