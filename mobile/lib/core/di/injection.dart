import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../config/api_mode.dart';
import '../config/app_config.dart';
import 'api_environments.dart';
import 'injection.config.dart';

final getIt = GetIt.instance;

/// Registers every `@injectable` class for [mode] (default
/// [AppConfig.apiMode]). Call once, before `runApp`.
@InjectableInit()
void configureDependencies({ApiMode? mode}) =>
    getIt.init(environment: apiEnvironment(mode ?? AppConfig.apiMode));
