import 'package:dio/dio.dart';
import 'errors.dart';

/// The single Dio instance every repository shares.
///
/// Kept deliberately dumb: it does not know about Riverpod, does not hold
/// app state, and does not retry. Its only job is turning "the server sent
/// back an error body" into the typed exceptions in errors.dart, so
/// repository code never has to touch `response.data['code']` directly.
class ApiClient {
  final Dio dio;

  ApiClient({required String baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            // The pre-call brief and morning briefing call Balanced/Reasoning
            // tier models server-side and can legitimately take a while —
            // see maxDuration on those routes in src/app/api. A short client
            // timeout would show a false "network error" during a real,
            // in-progress model call.
            receiveTimeout: const Duration(seconds: 120),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, handler) {
          final response = error.response;
          if (response != null && response.data is Map<String, dynamic>) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: apiExceptionFromBody(
                  response.data as Map<String, dynamic>,
                  response.statusCode,
                ),
                response: response,
                type: error.type,
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: NetworkException(error.message ?? 'Network request failed.'),
              type: error.type,
            ),
          );
        },
      ),
    );
  }
}
