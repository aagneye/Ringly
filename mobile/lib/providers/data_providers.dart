import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/briefing.dart';
import '../data/models/deal.dart';
import '../data/models/health.dart';
import '../data/models/today.dart';
import '../data/models/usage.dart';
import 'api_providers.dart';

/// Server configuration flags. Drives "not configured" notices.
final healthProvider = FutureProvider<HealthStatus>(
  (ref) => ref.watch(healthRepositoryProvider).fetch(),
);

/// Reminders, meetings and drafts for today.
final todayProvider = FutureProvider<TodaySnapshot>(
  (ref) => ref.watch(todayRepositoryProvider).fetch(),
);

/// The pipeline board, with drift signals already computed server-side.
final boardProvider = FutureProvider<Board>(
  (ref) => ref.watch(dealsRepositoryProvider).fetchBoard(),
);

/// Live Nemotron usage per tier.
final usageProvider = FutureProvider<UsageSummary>(
  (ref) => ref.watch(usageRepositoryProvider).fetch(),
);

/// The morning briefing (cached per day by the server).
final briefingProvider = FutureProvider<Briefing>(
  (ref) => ref.watch(briefingRepositoryProvider).fetch(),
);
