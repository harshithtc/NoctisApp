import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const String _kMsg = 'notif_messages';
  static const String _kCall = 'notif_calls';
  static const String _kSound = 'notif_sound';
  static const String _kVibrate = 'notif_vibration';

  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    setState(() {
      _messageNotifications = prefs.getBool(_kMsg) ?? true;
      _callNotifications = prefs.getBool(_kCall) ?? true;
      _soundEnabled = prefs.getBool(_kSound) ?? true;
      _vibrationEnabled = prefs.getBool(_kVibrate) ?? true;
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
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Categories
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Categories', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                SwitchListTile(
                  title: const Text('Message Notifications'),
                  subtitle: const Text('Get notified about new messages'),
                  value: _messageNotifications,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _messageNotifications = value);
                    _save(_kMsg, value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Call Notifications'),
                  subtitle: const Text('Get notified about incoming calls'),
                  value: _callNotifications,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _callNotifications = value);
                    _save(_kCall, value);
                  },
                ),

                const Divider(height: 24),

                // Behavior
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Behavior', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play sound for notifications'),
                  value: _soundEnabled,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _save(_kSound, value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate for notifications'),
                  value: _vibrationEnabled,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    setState(() => _vibrationEnabled = value);
                    _save(_kVibrate, value);
                  },
                ),

                // Info
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.info_outline, color: scheme.primary),
                  title: const Text('System settings'),
                  subtitle: const Text(
                    'On some devices, you may also need to allow notifications in system settings for full functionality.',
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Open system settings manually to adjust app notifications'),
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
