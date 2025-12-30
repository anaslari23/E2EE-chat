class AuthenticatedUser {
  final int id;
  final String username;
  final String accessToken;
  final bool needsSetup;

  AuthenticatedUser({
    required this.id,
    required this.username,
    required this.accessToken,
    this.needsSetup = false,
  });

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      accessToken: json['access_token'] ?? '',
      needsSetup: json['needs_setup'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'access_token': accessToken,
    };
  }
}
