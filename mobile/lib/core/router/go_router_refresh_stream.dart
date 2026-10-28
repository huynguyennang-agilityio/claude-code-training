import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a stream (such as `AuthBloc.stream`) into the [Listenable] that
/// `GoRouter.refreshListenable` expects, so the router re-runs `redirect`
/// whenever the stream emits.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
