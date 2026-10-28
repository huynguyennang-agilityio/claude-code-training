import 'package:dio/dio.dart';

/// Hands out the authenticated [Dio] when it is first needed. For classes
/// that the authenticated [Dio] itself depends on (the auth repository is its
/// token handler), so the dependency graph has no cycle.
class DioProvider {
  const DioProvider(this._create);

  final Dio Function() _create;

  Dio call() => _create();
}

/// Creates a [Dio] for the StrideQuest API.
///
/// Paths are joined to [baseUrl], so a base such as `https://example.com/api`
/// keeps its `/api` prefix, with or without a trailing slash. Request paths
/// must be relative (`auth/signin`, not `/auth/signin`).
Dio createDio({
  required String baseUrl,
  Duration timeout = const Duration(seconds: 15),
  List<Interceptor> interceptors = const [],
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: timeout,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      contentType: Headers.jsonContentType,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.addAll(interceptors);
  return dio;
}
