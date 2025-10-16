import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/models/message.dart';
import '../../../data/services/media_compression_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(String)? onImageUploaded;

  const ImagePickerWidget({
    super.key,
    this.onImageUploaded,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  final MediaCompressionService _compressionService = MediaCompressionService();

  bool _isWorking = false;
  double _progress = 0.0;

  @override
  void dispose() {
    _compressionService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isWorking) return;

    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() {
        _isWorking = true;
        _progress = 0.0;
      });

      // Compress image
      final original = File(picked.path);
      final compressed = await _compressionService.compressImage(original);
      setState(() => _progress = 0.5);

      // Get providers
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();

      // TODO: Replace with real upload (Cloudinary/S3) in Phase 2
      // final formData = FormData.fromMap({
      //   'file': await MultipartFile.fromFile(compressed.path),
      // });
      // final response = await ApiService().uploadImage(formData, encrypted: false);
      // final imageUrl = response.data['url'] as String;

      // Simulate upload
      await Future.delayed(const Duration(seconds: 1));
      final imageUrl = 'https://example.com/images/${compressed.path.split('/').last}';

      setState(() => _progress = 1.0);

      // Send an image message (content is a placeholder text; encrypted by provider)
      await chat.sendMessage(
        receiverId: auth.currentUser!.partnerId ?? '',
        content: '[Image]',
        currentUser: auth.currentUser!,
        type: MessageType.image,
        mediaUrl: imageUrl,
      );

      widget.onImageUploaded?.call(imageUrl);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _progress = 0.0;
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
            if (_isWorking)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Uploading image...'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toInt()}%'),
                  ],
                ),
              )
            else ...[
              ListTile(
                leading: Icon(Icons.camera_alt, color: scheme.primary),
                title: const Text('Take Photo'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: scheme.secondary),
                title: const Text('Choose from Gallery'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
