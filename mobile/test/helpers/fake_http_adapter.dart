import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHttpHandler = Future<ResponseBody> Function(RequestOptions request);

/// A Dio [HttpClientAdapter] that answers every request with [handler] and
/// records what was sent, so tests never touch the network.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FakeHttpHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody textBody(
  String body,
  int status, {
  Map<String, String> headers = const {},
}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      for (final entry in headers.entries) entry.key: [entry.value],
    },
  );
}

ResponseBody jsonBody(
  Object body,
  int status, {
  Map<String, String> headers = const {},
}) {
  return textBody(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json', ...headers},
  );
}

/// The JSON body a request was sent with.
Object? sentJson(RequestOptions request) => jsonDecode(request.data as String);
