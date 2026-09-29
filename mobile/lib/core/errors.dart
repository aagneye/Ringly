/// Mirrors the error shape every Ringly API route returns on failure
/// (see src/lib/api.ts `ApiErrorBody` on the server):
///   { "error": "message", "code": "machine_readable_code", "hint": "..." }
///
/// The Dart-side exception hierarchy exists so UI code can `catch` on a
/// specific failure type (e.g. "Nebius isn't configured") instead of string-
/// matching a `code` field at every call site.
library;

/// Base type for every error thrown by a repository. Carries the raw fields
/// from the server response so a generic handler can still show something
/// useful for codes that don't have a dedicated subclass below.
class RinglyApiException implements Exception {
  final String message;
  final String code;
  final String? hint;
  final int? statusCode;

  const RinglyApiException({
    required this.message,
    required this.code,
    this.hint,
    this.statusCode,
  });

  @override
  String toString() => 'RinglyApiException($code): $message';
}

/// code: nebius_not_configured — NEBIUS_API_KEY missing on the server.
class NebiusNotConfiguredException extends RinglyApiException {
  const NebiusNotConfiguredException({required super.message, super.hint})
      : super(code: 'nebius_not_configured', statusCode: 503);
}

/// code: database_not_configured — DATABASE_URL missing on the server.
class DatabaseNotConfiguredException extends RinglyApiException {
  const DatabaseNotConfiguredException({required super.message, super.hint})
      : super(code: 'database_not_configured', statusCode: 503);
}

/// code: transcription_unavailable — voice transcription failed or is
/// unreachable; the recorder UI should offer the "type instead" fallback.
class TranscriptionUnavailableException extends RinglyApiException {
  const TranscriptionUnavailableException({required super.message, super.hint})
      : super(code: 'transcription_unavailable', statusCode: 503);
}

/// code: deal_not_found
class DealNotFoundException extends RinglyApiException {
  const DealNotFoundException({required super.message})
      : super(code: 'deal_not_found', statusCode: 404);
}

/// code: bad_model_output — the model didn't return usable structured JSON.
class BadModelOutputException extends RinglyApiException {
  const BadModelOutputException({required super.message})
      : super(code: 'bad_model_output', statusCode: 502);
}

/// code: model_call_failed — the Nebius call itself failed (network, 5xx, etc).
class ModelCallFailedException extends RinglyApiException {
  const ModelCallFailedException({required super.message})
      : super(code: 'model_call_failed', statusCode: 502);
}

/// A network-level failure (no response at all — timeout, DNS, offline).
/// Distinct from [RinglyApiException], which means the server *did* respond,
/// just with an error body.
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Builds the right typed exception from a decoded error body. Falls back to
/// the generic [RinglyApiException] for codes without a dedicated subclass
/// (invalid_body, missing_audio, empty_audio, audio_too_large,
/// empty_transcript, missing_transcript, transcript_too_large,
/// draft_not_found, reminder_not_found, event_not_found, missing_question,
/// question_too_large, unauthorised, internal_error — these are shown via
/// their `message` directly, they don't need distinct UI branches).
RinglyApiException apiExceptionFromBody(
  Map<String, dynamic> body,
  int? statusCode,
) {
  final message = body['error'] as String? ?? 'Something went wrong.';
  final code = body['code'] as String? ?? 'internal_error';
  final hint = body['hint'] as String?;

  switch (code) {
    case 'nebius_not_configured':
      return NebiusNotConfiguredException(message: message, hint: hint);
    case 'database_not_configured':
      return DatabaseNotConfiguredException(message: message, hint: hint);
    case 'transcription_unavailable':
      return TranscriptionUnavailableException(message: message, hint: hint);
    case 'deal_not_found':
      return DealNotFoundException(message: message);
    case 'bad_model_output':
      return BadModelOutputException(message: message);
    case 'model_call_failed':
      return ModelCallFailedException(message: message);
    default:
      return RinglyApiException(
        message: message,
        code: code,
        hint: hint,
        statusCode: statusCode,
      );
  }
}
