import 'package:equatable/equatable.dart';

/// A figure the app reads from Apple Health or Health Connect.
enum HealthMetric {
  steps('Steps'),
  calories('Calories'),
  distance('Distance'),
  sleep('Sleep time');

  const HealthMetric(this.label);

  final String label;

  /// Steps count toward challenges, so the Active tab cannot be used without
  /// them. The others are shown, and sent, only when the user allows them.
  bool get isRequired => this == steps;
}

/// Where the user stands with health data access.
enum HealthAccessStatus {
  /// Steps may be read.
  granted,

  /// Steps may not be read yet: the app can still ask.
  denied,

  /// The system will not ask again: only the Settings app can turn it on.
  permanentlyDenied,

  /// This phone cannot give health data (Health Connect is missing or too old).
  unavailable,
}

/// Why, and how, the user should hear about health access, if at all.
enum HealthNotice {
  /// Nothing to tell.
  none,

  /// The system dialog can still show, so the app can ask.
  askable,

  /// Only the Settings app can turn steps on.
  settings,

  /// Health Connect is missing or too old.
  install,

  /// Access cannot be confirmed and the last days read 0 steps.
  noSteps,
}

/// The status, and the metrics the app may read. [allowed] is empty unless the
/// status is [HealthAccessStatus.granted].
class HealthAccess extends Equatable {
  const HealthAccess(
    this.status, {
    this.allowed = const {},
    this.confirmed = true,
  });

  const HealthAccess.denied() : this(HealthAccessStatus.denied);

  const HealthAccess.permanentlyDenied()
    : this(HealthAccessStatus.permanentlyDenied);

  const HealthAccess.unavailable() : this(HealthAccessStatus.unavailable);

  final HealthAccessStatus status;
  final Set<HealthMetric> allowed;

  /// False when the platform does not reveal whether reading is allowed (iOS
  /// after the dialog was shown), so a granted status is only a guess.
  final bool confirmed;

  bool get isGranted => status == HealthAccessStatus.granted;

  @override
  List<Object?> get props => [status, allowed, confirmed];
}
