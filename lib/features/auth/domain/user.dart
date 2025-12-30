class AuthenticatedUser {
  final int id;
  final String username;
  final String accessToken;

  AuthenticatedUser({
    required this.id,
    required this.username,
    required this.accessToken,
  });

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      accessToken: json['access_token'] ?? '',
    );
  }
}
