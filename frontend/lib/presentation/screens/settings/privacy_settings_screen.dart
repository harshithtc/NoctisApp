import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  static const String _kRead = 'privacy_read_receipts';
  static const String _kSeen = 'privacy_last_seen';
  static const String _kTyping = 'privacy_typing';

  bool _readReceipts = true;
  bool _lastSeen = true;
  bool _typingIndicator = true;

  bool _loading = true;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    setState(() {
      _readReceipts = prefs.getBool(_kRead) ?? true;
      _lastSeen = prefs.getBool(_kSeen) ?? true;
      _typingIndicator = prefs.getBool(_kTyping) ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Presence
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Presence', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                SwitchListTile(
                  title: const Text('Last Seen'),
                  subtitle: const Text('Show when you were last online'),
                  value: _lastSeen,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _lastSeen = value);
                    _save(_kSeen, value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Typing Indicator'),
                  subtitle: const Text('Show when you are typing'),
                  value: _typingIndicator,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _typingIndicator = value);
                    _save(_kTyping, value);
                  },
                ),

                const Divider(height: 24),

                // Messaging
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Messaging', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                SwitchListTile(
                  title: const Text('Read Receipts'),
                  subtitle: const Text('Let others know when you read their messages'),
                  value: _readReceipts,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _readReceipts = value);
                    _save(_kRead, value);
                  },
                ),

                const Divider(height: 24),

                // Security
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Security', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Change password - Coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('End-to-end encryption'),
                  subtitle: const Text('Messages are encrypted on your device before sending'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('E2E encryption is enabled by default for messages'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
