import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';
import 'package:stridequest/features/auth/data/models/auth_user_model.dart';
import 'package:stridequest/features/auth/data/models/token_pair_model.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

final testUser = AuthUserModel(
  id: 'user-1',
  email: 'runner@example.com',
  displayName: 'Lan Runner',
  createdAt: DateTime.utc(2026, 10, 13, 9, 55),
);

TokenPairModel testTokens([int n = 1]) => TokenPairModel(
  accessToken: 'access-$n',
  refreshToken: 'refresh-$n',
  expiresIn: const Duration(minutes: 15),
);

AuthSessionModel testSession([int n = 1]) =>
    AuthSessionModel(user: testUser, tokens: testTokens(n));
