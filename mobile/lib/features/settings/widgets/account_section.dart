import 'package:flutter/material.dart';

import 'settings_section.dart';

/// "Account": who is signed in, plus where the identity used to sign emails
/// actually comes from (the server env, not the app).
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsSection(
      title: 'Account',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline),
          title: Text('Profile'),
          subtitle: Text(
            'test123@gmail.com\n'
            'Your name, email and timezone for signing follow-up emails come '
            'from the server\'s RINGLY_USER_* settings, not from this app.',
          ),
          isThreeLine: true,
        ),
      ],
    );
  }
}
