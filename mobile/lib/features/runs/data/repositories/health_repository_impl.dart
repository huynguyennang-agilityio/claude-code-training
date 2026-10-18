import 'package:injectable/injectable.dart';

import '../../domain/entities/health_access.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_data_source.dart';
import '../datasources/health_prompt_store.dart';

/// Works out [HealthAccessStatus] from what the platform says and from how often
/// the system dialog has been shown.
///
/// - **Android** says which metrics are allowed. Steps allowed: granted. Not
///   allowed: denied, and permanently denied once the dialog has been shown
///   twice, when Health Connect stops asking.
/// - **iOS** never says whether a read was refused. The dialog is shown once;
///   after it was shown the app can only treat access as granted, and a refused
///   read shows as 0 steps. Before it was shown the status is denied.
@LazySingleton(as: HealthRepository)
class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(this._source, this._prompts);

  /// How many times Health Connect shows its dialog before it stops asking.
  static const androidDialogLimit = 2;

  final HealthDataSource _source;
  final HealthPromptStore _prompts;

  @override
  Future<HealthAccess> checkAccess() async {
    if (!await _source.isAvailable()) return const HealthAccess.unavailable();
    final asked = await _prompts.askedCount();
    final allowed = await _source.allowedMetrics();
    if (allowed == null) {
      // The platform will not say: the dialog having been shown is all we know.
      return asked > 0
          ? HealthAccess(
              HealthAccessStatus.granted,
              allowed: HealthMetric.values.toSet(),
            )
          : const HealthAccess.denied();
    }
    if (allowed.contains(HealthMetric.steps)) {
      return HealthAccess(HealthAccessStatus.granted, allowed: allowed);
    }
    return asked >= androidDialogLimit
        ? const HealthAccess.permanentlyDenied()
        : const HealthAccess.denied();
  }

  @override
  Future<HealthAccess> requestAccess() async {
    if (!await _source.isAvailable()) return const HealthAccess.unavailable();
    final shown = await _source.requestAuthorization();
    if (shown) await _prompts.recordAsked();
    final access = await checkAccess();
    // A dialog that could not be shown leaves the user where they were; on iOS
    // that would read as "asked once", so it must not count.
    return shown || access.isGranted ? access : const HealthAccess.denied();
  }

  @override
  Future<void> openSettings() => _source.openSettings();

  @override
  Future<void> installHealthConnect() => _source.installHealthConnect();
}
