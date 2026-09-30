import '../json.dart';

/// GET /api/health — which server-side subsystems are configured.
///
/// Each flag drives a "not configured" notice rather than an error, mirroring
/// the backend's explain-what's-missing design.
class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.nebius,
    required this.database,
    required this.tavily,
  });

  final bool ok;
  final bool nebius;
  final bool database;
  final bool tavily;

  factory HealthStatus.fromJson(Json json) => HealthStatus(
        ok: readBool(json, 'ok'),
        nebius: readBool(json, 'nebius'),
        database: readBool(json, 'database'),
        tavily: readBool(json, 'tavily'),
      );

  /// Nebius and the database are both required for the agent loop to run.
  bool get canProcessMemos => nebius && database;
}
