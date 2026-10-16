import 'package:dio/dio.dart';

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
