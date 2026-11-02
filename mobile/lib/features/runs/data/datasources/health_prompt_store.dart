import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Remembers how many times the system's health permission dialog was shown,
/// because the system does not say when it will stop asking.
abstract interface class HealthPromptStore {
  Future<int> askedCount();

  Future<void> recordAsked();

  /// When the health explainer was last shown, or null if never.
  Future<DateTime?> explainerShownAt();

  Future<void> recordExplainerShown(DateTime at);
}

/// A [HealthPromptStore] kept in the device's secure storage.
@LazySingleton(as: HealthPromptStore)
class SecureHealthPromptStore implements HealthPromptStore {
  SecureHealthPromptStore(this._storage);

  static const _key = 'health_permission_asked';

  static const _explainerKey = 'health_explainer_shown_at';

  final FlutterSecureStorage _storage;

  @override
  Future<int> askedCount() async {
    try {
      return int.tryParse(await _storage.read(key: _key) ?? '') ?? 0;
    } on Exception {
      return 0;
    }
  }

  @override
  Future<void> recordAsked() async {
    try {
      await _storage.write(key: _key, value: '${await askedCount() + 1}');
    } on Exception {
      // Without storage the count restarts with the app; asking still works.
    }
  }

  @override
  Future<DateTime?> explainerShownAt() async {
    try {
      final raw = await _storage.read(key: _explainerKey);
      return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> recordExplainerShown(DateTime at) async {
    try {
      await _storage.write(
        key: _explainerKey,
        value: at.toUtc().toIso8601String(),
      );
    } on Exception {
      // Without storage the explainer may show again after a restart.
    }
  }
}
