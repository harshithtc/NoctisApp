import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/message.dart';
import '../../../core/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final String decryptedContent;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSent,
    required this.decryptedContent,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bubbleTheme = theme.extension<ChatBubbleTheme>();

    final bgColor = isSent
        ? (bubbleTheme?.sentBubble ?? (theme.brightness == Brightness.dark ? const Color(0xFF1976D2) : const Color(0xFFE3F2FD)))
        : (bubbleTheme?.receivedBubble ?? (theme.brightness == Brightness.dark ? const Color(0xFF424242) : const Color(0xFFF5F5F5)));

    final textColor = isSent
        ? (bubbleTheme?.sentText ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87))
        : (bubbleTheme?.receivedText ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87));

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isSent ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isSent ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Message content
              Text(
                decryptedContent,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),

              // Time and status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  if (isSent) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(message.status, scheme, textColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status, ColorScheme scheme, Color baseTextColor) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.queued:
        icon = Icons.access_time;
        color = baseTextColor.withValues(alpha: .6);
        break;
      case MessageStatus.sending:
        icon = Icons.arrow_upward;
        color = baseTextColor.withValues(alpha: 0.6);
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = baseTextColor.withValues(alpha: 0.6);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = baseTextColor.withValues(alpha: 0.6);
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = scheme.primary;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = scheme.error;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}
