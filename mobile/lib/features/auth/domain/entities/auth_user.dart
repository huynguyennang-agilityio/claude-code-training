import 'package:equatable/equatable.dart';

/// A signed-in StrideQuest user.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  @override
  List<Object> get props => [id, email, displayName, createdAt];
}
