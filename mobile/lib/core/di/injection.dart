import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

/// Registers every `@injectable` class. Call once, before `runApp`.
@InjectableInit()
void configureDependencies() => getIt.init();
