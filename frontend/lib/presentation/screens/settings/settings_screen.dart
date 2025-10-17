// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'storage_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _initials(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return 'U';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : 'U').toUpperCase() +
        (parts[1].isNotEmpty ? parts[1][0] : '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primary,
              foregroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      _initials(user?.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            title: Text(user?.name ?? 'User'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: user == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: user)),
                    );
                  },
          ),

          const Divider(),

          // Theme Section
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              themeProvider.themeMode == ThemeMode.light
                  ? 'Light'
                  : themeProvider.themeMode == ThemeMode.dark
                      ? 'Dark'
                      : 'System',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showThemeDialog(context, themeProvider);
            },
          ),

          // Notifications
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),

          // Privacy & Security
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Privacy & Security'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PrivacySettingsScreen()),
              );
            },
          ),

          // Storage
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const StorageSettingsScreen()),
              );
            },
          ),

          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'NoctisApp',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.nightlight_round, size: 48),
                children: const [
                  Text('Secure chat application for couples'),
                ],
              );
            },
          ),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                themeProvider.setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
