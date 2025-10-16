import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/message_input.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../settings/settings_screen.dart';
import '../../../data/models/message.dart';
import '../../../data/services/encryption_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isUserTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    if (authProvider.currentUser != null) {
      final encryptionKey = await EncryptionService.getOrCreateEncryptionKey();
      if (!mounted) return;
      await chatProvider.initialize(
        encryptionKey,
        authProvider.currentUser!,
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.fetchMoreMessages();
    }
  }

  void _onTyping(bool isTyping) {
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();

    if (isTyping && !_isUserTyping) {
      _isUserTyping = true;
      chat.sendTypingIndicator(
        auth.currentUser!.partnerId ?? '',
        true,
      );

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isUserTyping = false;
        chat.sendTypingIndicator(
          auth.currentUser!.partnerId ?? '',
          false,
        );
      });
    }
  }

  void _onMessageSent() {
    _typingTimer?.cancel();
    if (_isUserTyping) {
      _isUserTyping = false;
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();
      chat.sendTypingIndicator(
        auth.currentUser!.partnerId ?? '',
        false,
      );
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.currentUser?.name ?? 'Chat',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              chat.isConnected ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: chat.isConnected ? scheme.primary : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () async {
              if (auth.currentUser?.partnerId == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please connect with your partner first'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Voice Call'),
                  content: const Text('Start a voice call?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Call'),
                    ),
                  ],
                ),
              );
              if (!mounted) return;
              if (confirmed != null && confirmed == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice calls coming in Phase 2'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text('Clear Messages'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'clear') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Messages'),
                    content: const Text(
                      'Are you sure you want to clear all messages? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (!mounted) return;
                if (confirmed == true) {
                  await chat.clearAllMessages();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Messages cleared')),
                  );
                }
              } else if (value == 'logout') {
                await auth.logout();
                if (!mounted) return;
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!connectivity.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text('No Internet Connection',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          if (chat.queuedMessages.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: scheme.primary.withAlpha((0.08 * 255).round()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chat.queuedMessages.length} message(s) queued',
                    style: TextStyle(color: scheme.primary),
                  ),
                ],
              ),
            ),
          if (chat.isLoading && chat.hasMoreMessages)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Expanded(
            child: chat.isLoading && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey.withAlpha((0.5 * 255).round()),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount:
                            chat.messages.length + (chat.isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0 && chat.isTyping) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: TypingIndicator(),
                            );
                          }
                          final messageIndex =
                              chat.isTyping ? index - 1 : index;
                          final message = chat.messages[messageIndex];
                          final isSent =
                              message.senderId == auth.currentUser?.id;
                          final decryptedContent =
                              chat.decryptMessage(message);
                          return ChatBubble(
                            message: message,
                            isSent: isSent,
                            decryptedContent: decryptedContent,
                            onLongPress: () {
                              _showMessageOptions(context, message, isSent);
                            },
                          );
                        },
                      ),
          ),
          MessageInput(
            onSend: (content) async {
              await chat.sendMessage(
                receiverId: auth.currentUser!.partnerId ?? '',
                content: content,
                currentUser: auth.currentUser!,
              );
              _onMessageSent();
            },
            onTyping: _onTyping,
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Message message, bool isSent) {
    final chat = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(
                  ClipboardData(text: chat.decryptMessage(message)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                chat.setReplyMessage(message);
              },
            ),
            if (isSent)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete for Me'),
                onTap: () async {
                  Navigator.pop(context);
                  await chat.deleteMessage(message.id, false);
                },
              ),
            if (isSent)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Delete for Everyone'),
                onTap: () async {
                  Navigator.pop(context);
                  await chat.deleteMessage(message.id, true);
                },
              ),
          ],
        ),
      ),
    );
  }
}
