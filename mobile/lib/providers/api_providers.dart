import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/env.dart';
import '../data/repositories/briefing_repository.dart';
import '../data/repositories/deals_repository.dart';
import '../data/repositories/drafts_repository.dart';
import '../data/repositories/health_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/reminders_repository.dart';
import '../data/repositories/today_repository.dart';
import '../data/repositories/usage_repository.dart';

/// Which backend the app talks to. Overridden by each entrypoint
/// (main_dev.dart → emulator host, main_prod.dart → deployed API), so no
/// repository ever hardcodes a URL.
final baseUrlProvider = Provider<String>((ref) => Env.emulatorBaseUrl);

/// The one shared HTTP client.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: ref.watch(baseUrlProvider)),
);

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(apiClientProvider)),
);

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(apiClientProvider)),
);

final dealsRepositoryProvider = Provider<DealsRepository>(
  (ref) => DealsRepository(ref.watch(apiClientProvider)),
);

final usageRepositoryProvider = Provider<UsageRepository>(
  (ref) => UsageRepository(ref.watch(apiClientProvider)),
);

final briefingRepositoryProvider = Provider<BriefingRepository>(
  (ref) => BriefingRepository(ref.watch(apiClientProvider)),
);

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(apiClientProvider)),
);

final draftsRepositoryProvider = Provider<DraftsRepository>(
  (ref) => DraftsRepository(ref.watch(apiClientProvider)),
);

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => RemindersRepository(ref.watch(apiClientProvider)),
);
