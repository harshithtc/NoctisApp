import 'dart:async';
import 'dart:io';
// import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import '../../core/constants/app_constants.dart';

class MediaCompressionService {
  Subscription? _progressSubscription;
  final _progressController = StreamController<double>.broadcast();

  // Expose compression progress (0.0..1.0)
  Stream<double> get compressionProgress => _progressController.stream;

  /// Compress an image to meet size and dimension constraints.
  /// - Resizes if larger than max width/height.
  /// - Iteratively reduces JPEG quality until under max size or hits min quality.
  /// - Returns a new temp file (.jpg).
  Future<File> compressImage(
    File imageFile, {
    int? maxWidth,
    int? maxHeight,
    int? targetMaxKB,
    int minQuality = 50,
    int initialQuality = AppConstants.imageQuality,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('File-based image compression is not supported on web.');
    }

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }

    // Target constraints (fallback to AppConstants)
    final maxW = maxWidth ?? AppConstants.maxImageWidth;
    final maxH = maxHeight ?? AppConstants.maxImageHeight;
    final maxKB = targetMaxKB ?? AppConstants.maxImageSizeKB;

    // Resize to fit within the bounding box while preserving aspect ratio
    img.Image working = decoded;
    if (decoded.width > maxW || decoded.height > maxH) {
      final bool landscape = decoded.width >= decoded.height;
      working = img.copyResize(
        decoded,
        width: landscape ? maxW : null,
        height: landscape ? null : maxH,
        interpolation: img.Interpolation.linear,
      );
    }

    // Encode as JPEG and iteratively reduce quality until size <= target
    int quality = initialQuality.clamp(50, 95);
    Uint8List out = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    while (out.lengthInBytes > maxKB * 1024 && quality > minQuality) {
      quality -= 5;
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    // If still too large, attempt a second-pass downscale by 10% steps (up to 3 times)
    int downscalePasses = 0;
    while (out.lengthInBytes > maxKB * 1024 && downscalePasses < 3) {
      final newW = (working.width * 0.9).floor();
      final newH = (working.height * 0.9).floor();
      working = img.copyResize(working, width: newW, height: newH, interpolation: img.Interpolation.linear);
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
      downscalePasses += 1;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(filePath);
    await outFile.writeAsBytes(out, flush: true);
    return outFile;
    }

  /// Compress a video using platform-native encoder via video_compress.
  /// - Emits progress to [compressionProgress] as 0.0..1.0.
  /// - Returns a new File on success, or null on failure.
  Future<File?> compressVideo(
    File videoFile, {
    VideoQuality quality = VideoQuality.MediumQuality,
    bool includeAudio = true,
    bool deleteOrigin = false,
  }) async {
    if (kIsWeb) {
      // video_compress does not support web
      return videoFile;
    }
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      // Fallback: return original on unsupported platforms
      return videoFile;
    }

    try {
      _startProgressListener();
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        includeAudio: includeAudio,
        deleteOrigin: deleteOrigin,
      );
      if (info == null || info.file == null) {
        throw Exception('Video compression failed');
      }
      return info.file;
    } catch (e) {
      debugPrint('Video compression error: $e');
      return null;
    } finally {
      _stopProgressListener();
    }
  }

  /// Generate a thumbnail image for a video.
  /// Returns a File pointing to the generated thumbnail, or null if failed.
  Future<File?> getVideoThumbnail(
    File videoFile, {
    int quality = 75,
    int? positionMs,
  }) async {
    if (kIsWeb) {
      return null;
    }
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: quality.clamp(10, 100),
        position: positionMs ?? 0,
      );
      return thumb;
    } catch (e) {
      debugPrint('Thumbnail generation error: $e');
      return null;
    }
  }

  /// Cancel ongoing video compression (if any).
  void cancelCompression() {
    if (!kIsWeb) {
      VideoCompress.cancelCompression();
    }
    _stopProgressListener();
  }

  void _startProgressListener() {
    _progressSubscription?.unsubscribe();
    _progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
      // progress is 0..100 (double)
      _progressController.add((progress ) / 100.0);
    });
  }

  void _stopProgressListener() {
    _progressSubscription?.unsubscribe();
    _progressSubscription = null;
  }

  /// Cleanup resources and cached temp files for video_compress.
  Future<void> dispose() async {
    _stopProgressListener();
    await _progressController.close();
    if (!kIsWeb) {
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
    }
  }
}
