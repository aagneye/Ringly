import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ringly_mobile/core/api_client.dart';

/// A canned HTTP response for [FakeAdapter].
class FakeResponse {
  const FakeResponse(this.status, this.body);

  /// A 200 with a JSON body.
  const FakeResponse.ok(Object body) : this(200, body);

  final int status;
  final Object body;
}

/// A Dio adapter that answers from a route table instead of the network.
///
/// Keyed by `"METHOD /path"`. A handler may return a [FakeResponse] or throw
/// to simulate a connection failure. Every request is recorded so tests can
/// assert on what was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, FakeResponse Function(RequestOptions)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    final handler = routes[key];
    if (handler == null) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'No fake route for $key', 'code': 'not_found'}),
        404,
        headers: _jsonHeaders,
      );
    }
    final response = handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: _jsonHeaders,
    );
  }

  @override
  void close({bool force = false}) {}

  static final _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };
}

/// An [ApiClient] wired to [adapter] instead of a real socket.
ApiClient fakeClient(FakeAdapter adapter) {
  final client = ApiClient(baseUrl: 'http://test.local');
  client.dio.httpClientAdapter = adapter;
  return client;
}

/// A handler that simulates the device being offline.
FakeResponse offline(RequestOptions options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
