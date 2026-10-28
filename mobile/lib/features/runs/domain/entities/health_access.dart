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

/// The status, and the metrics the app may read. [allowed] is empty unless the
/// status is [HealthAccessStatus.granted].
class HealthAccess extends Equatable {
  const HealthAccess(this.status, {this.allowed = const {}});

  const HealthAccess.denied() : this(HealthAccessStatus.denied);

  const HealthAccess.permanentlyDenied()
    : this(HealthAccessStatus.permanentlyDenied);

  const HealthAccess.unavailable() : this(HealthAccessStatus.unavailable);

  final HealthAccessStatus status;
  final Set<HealthMetric> allowed;

  bool get isGranted => status == HealthAccessStatus.granted;

  @override
  List<Object?> get props => [status, allowed];
}
