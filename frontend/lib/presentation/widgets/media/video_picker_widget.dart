import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/models/message.dart';
import '../../../data/services/media_compression_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class VideoPickerWidget extends StatefulWidget {
  final Function(String)? onVideoUploaded;

  const VideoPickerWidget({
    super.key,
    this.onVideoUploaded,
  });

  @override
  State<VideoPickerWidget> createState() => _VideoPickerWidgetState();
}

class _VideoPickerWidgetState extends State<VideoPickerWidget> {
  final ImagePicker _picker = ImagePicker();
  final MediaCompressionService _compressionService = MediaCompressionService();

  StreamSubscription<double>? _progressSub;
  bool _isProcessing = false;
  double _compressionProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Listen to compression progress
    _progressSub = _compressionService.compressionProgress.listen((progress) {
      if (!mounted) return;
      setState(() => _compressionProgress = progress);
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _compressionService.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (video == null) return;

      setState(() {
        _isProcessing = true;
        _compressionProgress = 0.0;
      });

      // Compress video
      final videoFile = File(video.path);
      final compressedFile = await _compressionService.compressVideo(videoFile);
      if (compressedFile == null) {
        throw Exception('Video compression failed');
      }

      // Generate thumbnail for future preview (not used in MVP UI)
      await _compressionService.getVideoThumbnail(compressedFile);

      // Providers
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();

      // TODO: Replace with real upload in Phase 2
      // final formData = FormData.fromMap({
      //   'file': await MultipartFile.fromFile(compressedFile.path),
      // });
      // final response = await ApiService().uploadVideo(formData, encrypted: false);
      // final videoUrl = response.data['url'] as String;

      // Simulate upload
      await Future.delayed(const Duration(seconds: 2));
      final videoUrl =
          'https://example.com/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Send video message
      await chat.sendMessage(
        receiverId: auth.currentUser!.partnerId ?? '',
        content: '[Video]',
        currentUser: auth.currentUser!,
        type: MessageType.video,
        mediaUrl: videoUrl,
      );

      widget.onVideoUploaded?.call(videoUrl);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process video: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _compressionProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Compressing video...'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _compressionProgress),
                    const SizedBox(height: 8),
                    Text('${(_compressionProgress * 100).toInt()}%'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        _compressionService.cancelCompression();
                        setState(() {
                          _isProcessing = false;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              )
            else ...[
              ListTile(
                leading: Icon(Icons.videocam, color: scheme.error),
                title: const Text('Record Video'),
                onTap: () => _pickVideo(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.video_library, color: scheme.tertiary),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickVideo(ImageSource.gallery),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
