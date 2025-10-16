import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceRecorderWidget extends StatefulWidget {
  const VoiceRecorderWidget({super.key});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  int _recordDuration = 0; // seconds
  Timer? _timer;

  static const int _maxSeconds = 300; // 5 minutes

  void _startRecording() {
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordDuration++);
      if (_recordDuration >= _maxSeconds) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void _cancelAndClose() {
    _stopRecording();
    if (mounted) Navigator.pop(context);
  }

  void _sendRecording() {
    _stopRecording();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice messages - Coming in Phase 2')),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRecording ? Icons.fiber_manual_record : Icons.mic_none_outlined,
                  color: _isRecording ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isRecording ? 'Recording...' : 'Voice Message',
                  style: textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Timer and hint
            if (_isRecording) ...[
              Text(
                _formatDuration(_recordDuration),
                style: textTheme.headlineSmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Max 05:00',
                style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isRecording)
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: _cancelAndClose,
                  ),
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Semantics(
                    button: true,
                    label: _isRecording ? 'Stop recording' : 'Start recording',
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _isRecording ? scheme.error : scheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: scheme.onPrimary,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                if (_isRecording && _recordDuration > 0)
                  IconButton(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send, size: 28),
                    color: scheme.primary,
                    onPressed: _sendRecording,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Helper text
            Text(
              _isRecording ? 'Tap stop when done' : 'Tap to start recording',
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
