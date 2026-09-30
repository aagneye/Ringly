import 'package:dio/dio.dart';
import 'errors.dart';

/// Run a Dio request and surface the typed exception [ApiClient]'s interceptor
/// attached, instead of a raw [DioException].
///
/// Repositories wrap every call in this so UI code only ever sees
/// [RinglyApiException] (the server answered with an error body) or
/// [NetworkException] (no usable answer at all).
Future<T> apiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    final inner = error.error;
    if (inner is RinglyApiException) throw inner;
    if (inner is NetworkException) throw inner;
    throw NetworkException(error.message ?? 'Network request failed.');
  }
}

/// Decode a JSON object body, rejecting anything else with a clear message.
Map<String, dynamic> asJsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw const RinglyApiException(
    message: 'The server sent an unexpected response.',
    code: 'unexpected_response',
  );
}
