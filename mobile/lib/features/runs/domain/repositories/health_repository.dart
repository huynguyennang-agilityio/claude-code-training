import '../entities/health_access.dart';

/// Access to the health data of the device (Apple Health, Health Connect).
abstract interface class HealthRepository {
  /// Where access stands now, without asking the user anything.
  Future<HealthAccess> checkAccess();

  /// Asks the user for access (the system dialog), then says where it stands.
  /// The system shows its dialog once, or twice on Android; after that the
  /// answer is [HealthAccessStatus.permanentlyDenied] until Settings changes.
  Future<HealthAccess> requestAccess();

  /// Opens the system settings where the user can allow health data.
  Future<void> openSettings();

  /// Sends the user to the store to install Health Connect (Android).
  Future<void> installHealthConnect();
}
