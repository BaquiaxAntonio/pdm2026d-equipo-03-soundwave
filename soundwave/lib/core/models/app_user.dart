class AppUser {
  const AppUser({required this.id, required this.username, this.displayName});
  final String id;
  final String username;
  final String? displayName;

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
    id: map['id']! as String,
    username: map['username']! as String,
    displayName: map['display_name'] as String?,
  );
}
