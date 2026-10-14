/// A signed-in StrideQuest user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, email, displayName, createdAt);
}

/// The access and refresh tokens issued by the backend (`TokenPair`).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  /// Throws [FormatException] when `token_type` is not `bearer`.
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final tokenType = json['token_type'] as String;
    if (tokenType.toLowerCase() != 'bearer') {
      throw FormatException('Unsupported token_type: $tokenType');
    }
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: Duration(seconds: json['expires_in'] as int),
    );
  }

  final String accessToken;
  final String refreshToken;

  /// How long the access token is valid from when it was issued, from
  /// `expires_in`. The contract says to use this instead of a fixed lifetime.
  final Duration expiresIn;

  @override
  bool operator ==(Object other) =>
      other is AuthTokens &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.expiresIn == expiresIn;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresIn);
}

/// The result of signing up or signing in.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }

  final AuthUser user;
  final AuthTokens tokens;
}
