import 'errors.dart';

/// Turn any thrown error into one plain sentence for the UI.
///
/// "Not configured" errors are phrased as setup instructions rather than
/// failures, matching the server's explain-what's-missing design.
String friendlyError(Object error) {
  if (error is NebiusNotConfiguredException) {
    return 'The AI isn\'t set up on the server yet — add NEBIUS_API_KEY to the backend.';
  }
  if (error is DatabaseNotConfiguredException) {
    return 'The database isn\'t set up on the server yet — add DATABASE_URL to the backend.';
  }
  if (error is TranscriptionUnavailableException) {
    return 'Voice transcription is unavailable right now. You can type the note instead.';
  }
  if (error is NetworkException) {
    return 'Can\'t reach the Ringly server. Check your connection and pull to refresh.';
  }
  if (error is RinglyApiException) return error.message;
  return 'Something went wrong. Pull to refresh to try again.';
}

/// True when the error means "the backend is missing configuration", which
/// the UI shows as a calm setup notice instead of a red error.
bool isNotConfigured(Object error) =>
    error is NebiusNotConfiguredException || error is DatabaseNotConfiguredException;
