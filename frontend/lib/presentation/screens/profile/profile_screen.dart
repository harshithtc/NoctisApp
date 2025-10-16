import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/user.dart';

class ProfileScreen extends StatelessWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    return (parts[0].isNotEmpty ? parts[0][0] : 'U').toUpperCase() +
        (parts[1].isNotEmpty ? parts[1][0] : '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile - Coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: scheme.primary,
                  foregroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? Text(
                          _initials(user.name),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Chip(
                      avatar: Icon(
                        user.emailVerified ? Icons.verified : Icons.mark_email_unread_outlined,
                        color: user.emailVerified ? Colors.green : scheme.primary,
                        size: 18,
                      ),
                      label: Text(user.emailVerified ? 'Email verified' : 'Email unverified'),
                      backgroundColor:
                          user.emailVerified ? Colors.green.withValues(alpha: 0.12) : scheme.primary.withValues(alpha: 0.08),
                      side: BorderSide(color: user.emailVerified ? Colors.green : scheme.primary),
                    ),
                    if (user.phoneNumber != null)
                      Chip(
                        avatar: Icon(
                          user.phoneVerified ? Icons.verified : Icons.phone_enabled_outlined,
                          color: user.phoneVerified ? Colors.green : scheme.primary,
                          size: 18,
                        ),
                        label: Text(user.phoneVerified ? 'Phone verified' : 'Phone unverified'),
                        backgroundColor:
                            user.phoneVerified ? Colors.green.withValues(alpha: 0.12) : scheme.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: user.phoneVerified ? Colors.green : scheme.primary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(user.name),
            ),
          ),

          // Email
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(user.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    user.emailVerified ? Icons.verified : Icons.error_outline,
                    color: user.emailVerified ? Colors.green : Colors.orange,
                  ),
                  IconButton(
                    tooltip: 'Copy email',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: user.email));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Email copied')));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Phone (optional)
          if (user.phoneNumber != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(user.phoneNumber!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.phoneVerified)
                      const Icon(Icons.verified, color: Colors.green),
                    IconButton(
                      tooltip: 'Copy phone',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: user.phoneNumber!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Phone number copied')));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bio (optional)
          if (user.bio != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Bio'),
                subtitle: Text(user.bio!),
              ),
            ),

          // Partner (optional)
          if (user.partnerId != null && user.partnerId!.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Partner ID'),
                subtitle: Text(user.partnerId!),
                trailing: IconButton(
                  tooltip: 'Copy partner ID',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: user.partnerId!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Partner ID copied')));
                    }
                  },
                ),
              ),
            ),

          // Member since
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Member Since'),
              subtitle: Text(
                '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}',
              ),
            ),
          ),

          // Last seen (optional)
          if (user.lastSeen != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Last Seen'),
                subtitle: Text(
                  '${user.lastSeen!.toLocal()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
