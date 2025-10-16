import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../media/image_picker_widget.dart';
import '../media/video_picker_widget.dart';
import '../media/voice_recorder_widget.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(bool)? onTyping;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onTyping,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _isEmpty = true;

  // Common emojis for quick access
  static const List<String> _commonEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
    '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
    '😒', '😞', '😔', '😟', '😕', '🙁', '😣', '😖',
    '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '👍', '👎', '👌', '🤝', '🙏', '👏', '💪', '🎉',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    setState(() {
      _isEmpty = text.trim().isEmpty;
    });

    // Typing indicator
    if (widget.onTyping != null) {
      if (text.isNotEmpty) {
        widget.onTyping!(true);
        // Reset timer
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 2), () {
          widget.onTyping!(false);
        });
      } else {
        // Immediately mark not typing if cleared
        widget.onTyping!(false);
        _typingTimer?.cancel();
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    setState(() {
      _isEmpty = true;
    });

    if (widget.onTyping != null) {
      widget.onTyping!(false);
    }
  }

  void _insertEmoji(String emoji) {
    final currentText = _controller.text;
    final selection = _controller.selection;
    // If no selection, append to end
    final start = selection.start >= 0 ? selection.start : currentText.length;
    final end = selection.end >= 0 ? selection.end : currentText.length;

    final newText = currentText.replaceRange(start, end, emoji);
    _controller.text = newText;
    final newOffset = start + emoji.length;
    _controller.selection = TextSelection.collapsed(offset: newOffset);

    _focusNode.requestFocus();
    _onTextChanged(newText);
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 300,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _commonEmojis.length,
          itemBuilder: (context, index) {
            final e = _commonEmojis[index];
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _insertEmoji(e);
              },
              child: Center(
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showVoiceRecorder() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (context) => const VoiceRecorderWidget(),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 100MB)
        if (file.size > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File too large. Max size is 100MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Show upload progress
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Uploading ${file.name}...'),
                ],
              ),
            ),
          );

          // Simulate upload (replace with actual upload in Phase 2)
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) Navigator.pop(context);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${file.name} uploaded (simulated)')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      context,
                      icon: Icons.image,
                      label: 'Image',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => const ImagePickerWidget(),
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      context,
                      icon: Icons.videocam,
                      label: 'Video',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => const VideoPickerWidget(),
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      context,
                      icon: Icons.insert_drive_file,
                      label: 'File',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFile();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add attachment',
              onPressed: () {
                _showAttachmentOptions(context);
              },
            ),

            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade200
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Emoji',
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: _showEmojiPicker,
                    ),
                  ),
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send or voice button
            _isEmpty
                ? IconButton(
                    tooltip: 'Record voice',
                    icon: const Icon(Icons.mic_outlined),
                    onPressed: _showVoiceRecorder,
                  )
                : IconButton(
                    tooltip: 'Send',
                    icon: Icon(
                      Icons.send,
                      color: scheme.primary,
                    ),
                    onPressed: _sendMessage,
                  ),
          ],
        ),
      ),
    );
  }
}
