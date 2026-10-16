/// Base class for typed, user-facing errors raised by repositories.
///
/// Pure Dart, so domain layers can depend on it.
abstract class Failure implements Exception {
  const Failure();

  /// A message that is safe to show the user.
  String get message;
}
