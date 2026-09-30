import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'widgets/account_section.dart';
import 'widgets/ai_section.dart';
import 'widgets/app_section.dart';
import 'widgets/connections_section.dart';
import 'widgets/data_privacy_section.dart';
import 'widgets/voice_section.dart';

/// The full-screen settings page, opened from the drawer.
///
/// Grouped into sections that each own their own state and providers, so the
/// screen itself is just a list of them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: const [
          AccountSection(),
          ConnectionsSection(),
          VoiceSection(),
          DataPrivacySection(),
          AiSection(),
          AppSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
