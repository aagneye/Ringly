import '../../core/api_call.dart';
import '../../core/api_client.dart';

/// POST /api/drafts/[id] — the human tap that resolves an email draft.
///
/// Ringly never sends mail itself. "Approve" records that the user took the
/// draft into their own mail client; "discard" throws it away.
class DraftsRepository {
  const DraftsRepository(this._client);

  final ApiClient _client;

  Future<void> approve(String id, {String? subject, String? body}) => apiCall(() async {
        await _client.dio.post<Object?>(
          '/api/drafts/${Uri.encodeComponent(id)}',
          data: {
            'action': 'approve',
            if (subject != null && subject.isNotEmpty) 'subject': subject,
            if (body != null && body.isNotEmpty) 'body': body,
          },
        );
      });

  Future<void> discard(String id) => apiCall(() async {
        await _client.dio.post<Object?>(
          '/api/drafts/${Uri.encodeComponent(id)}',
          data: {'action': 'discard'},
        );
      });
}
