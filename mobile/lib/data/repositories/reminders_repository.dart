import '../../core/api_call.dart';
import '../../core/api_client.dart';

/// PATCH /api/reminders/[id] — tick off, dismiss or reopen a reminder.
class RemindersRepository {
  const RemindersRepository(this._client);

  final ApiClient _client;

  Future<void> setStatus(String id, String status) => apiCall(() async {
        await _client.dio.patch<Object?>(
          '/api/reminders/${Uri.encodeComponent(id)}',
          data: {'status': status},
        );
      });

  Future<void> complete(String id) => setStatus(id, 'done');
  Future<void> dismiss(String id) => setStatus(id, 'dismissed');
  Future<void> reopen(String id) => setStatus(id, 'pending');
}
