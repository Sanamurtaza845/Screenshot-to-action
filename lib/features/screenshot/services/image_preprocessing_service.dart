import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Metadata describing what enhancements were applied during preprocessing.
class PreprocessingMetadata {
  final bool isDarkModeInverted;
  final bool wasUpscaled;
  final bool wasDownscaled;
  final bool wasContrastEnhanced;
  final int originalWidth;
  final int originalHeight;
  final int processedWidth;
  final int processedHeight;
  final double averageLuminance;

  const PreprocessingMetadata({
    required this.isDarkModeInverted,
    required this.wasUpscaled,
    required this.wasDownscaled,
    required this.wasContrastEnhanced,
    required this.originalWidth,
    required this.originalHeight,
    required this.processedWidth,
    required this.processedHeight,
    required this.averageLuminance,
  });

  String get summary {
    final parts = <String>[];

    if (isDarkModeInverted) parts.add('Dark Mode Inverted');
    if (wasUpscaled) parts.add('Resolution Upscaled');
    if (wasDownscaled) parts.add('Size Normalized');
    if (wasContrastEnhanced) parts.add('Contrast Enhanced');

    if (parts.isEmpty) parts.add('Standard Optimization');

    return parts.join(', ');
  }
}

/// Result containing the path to the cleaned/preprocessed image and metadata.
class PreprocessedImageResult {
  final File file;
  final PreprocessingMetadata metadata;
  final bool isTemporary;

  const PreprocessedImageResult({
    required this.file,
    required this.metadata,
    this.isTemporary = true,
  });

  /// Cleans up temporary file generated for OCR processing.
  Future<void> cleanup() async {
    if (isTemporary) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Temporary file cleanup warning: $e');
      }
    }
  }
}

/// Service to preprocess screenshots before OCR.
class ImagePreprocessingService {
  /// Runs CPU-intensive image processing in a background isolate.
  Future<PreprocessedImageResult> preprocess(String inputPath) async {
    final result = await compute(
      _preprocessImageInBackground,
      inputPath,
      debugLabel: 'Screenshot Image Preprocessing',
    );

    if (result['error'] != null) {
      throw FileNotFoundException(result['error'] as String);
    }

    return PreprocessedImageResult(
      file: File(result['filePath'] as String),
      isTemporary: result['isTemporary'] as bool,
      metadata: PreprocessingMetadata(
        isDarkModeInverted: result['isDarkModeInverted'] as bool,
        wasUpscaled: result['wasUpscaled'] as bool,
        wasDownscaled: result['wasDownscaled'] as bool,
        wasContrastEnhanced: result['wasContrastEnhanced'] as bool,
        originalWidth: result['originalWidth'] as int,
        originalHeight: result['originalHeight'] as int,
        processedWidth: result['processedWidth'] as int,
        processedHeight: result['processedHeight'] as int,
        averageLuminance: result['averageLuminance'] as double,
      ),
    );
  }
}

/// Top-level function required by compute().
/// All CPU-intensive image processing happens in this isolate.
Future<Map<String, dynamic>> _preprocessImageInBackground(
  String inputPath,
) async {
  final inputFile = File(inputPath);

  if (!await inputFile.exists()) {
    return {
      'error': 'Screenshot file not found: $inputPath',
    };
  }

  final bytes = await inputFile.readAsBytes();
  final originalImage = img.decodeImage(bytes);

  // If decoding fails, use the original image as fallback.
  if (originalImage == null) {
    return {
      'filePath': inputPath,
      'isTemporary': false,
      'isDarkModeInverted': false,
      'wasUpscaled': false,
      'wasDownscaled': false,
      'wasContrastEnhanced': false,
      'originalWidth': 0,
      'originalHeight': 0,
      'processedWidth': 0,
      'processedHeight': 0,
      'averageLuminance': 128.0,
    };
  }

  final originalWidth = originalImage.width;
  final originalHeight = originalImage.height;

  img.Image workingImage = originalImage;

  // 1. RESOLUTION SCALING
  bool wasUpscaled = false;
  bool wasDownscaled = false;

  final minDimension = min(originalWidth, originalHeight);
  final maxDimension = max(originalWidth, originalHeight);

  if (minDimension < 1000) {
    final scaleFactor = (1200.0 / minDimension).clamp(1.2, 2.0);

    final targetWidth = (originalWidth * scaleFactor).round();
    final targetHeight = (originalHeight * scaleFactor).round();

    workingImage = img.copyResize(
      workingImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    wasUpscaled = true;
  } else if (maxDimension > 3200) {
    final scaleFactor = 3000.0 / maxDimension;

    final targetWidth = (originalWidth * scaleFactor).round();
    final targetHeight = (originalHeight * scaleFactor).round();

    workingImage = img.copyResize(
      workingImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    wasDownscaled = true;
  }

  // 2. DARK MODE DETECTION & INVERSION
  final avgLuminance = _calculateAverageLuminance(workingImage);

  bool isDarkModeInverted = false;

  if (avgLuminance < 115.0) {
    workingImage = img.invert(workingImage);
    isDarkModeInverted = true;
  }

  // 3. GRAYSCALE CONVERSION
  workingImage = img.grayscale(workingImage);

  // 4. CONTRAST ENHANCEMENT
  workingImage = img.contrast(workingImage, contrast: 135);

  const wasContrastEnhanced = true;

  // 5. ENCODE & SAVE OPTIMIZED IMAGE
  final processedBytes = img.encodePng(workingImage);

  final timestamp = DateTime.now().microsecondsSinceEpoch;

  final tempFilePath =
      '${Directory.systemTemp.path}/ocr_preprocessed_${timestamp}_$minDimension.png';

  final tempFile = File(tempFilePath);

  await tempFile.writeAsBytes(processedBytes, flush: true);

  return {
    'filePath': tempFilePath,
    'isTemporary': true,
    'isDarkModeInverted': isDarkModeInverted,
    'wasUpscaled': wasUpscaled,
    'wasDownscaled': wasDownscaled,
    'wasContrastEnhanced': wasContrastEnhanced,
    'originalWidth': originalWidth,
    'originalHeight': originalHeight,
    'processedWidth': workingImage.width,
    'processedHeight': workingImage.height,
    'averageLuminance': avgLuminance,
  };
}

/// Calculates average luminance using perceptual weights.
double _calculateAverageLuminance(img.Image image) {
  double total = 0;
  int samples = 0;

  final stepX = max(1, (image.width / 100).round());
  final stepY = max(1, (image.height / 100).round());

  for (int y = 0; y < image.height; y += stepY) {
    for (int x = 0; x < image.width; x += stepX) {
      final pixel = image.getPixel(x, y);

      final lum =
          0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;

      total += lum;
      samples++;
    }
  }

  return samples > 0 ? total / samples : 128.0;
}

class FileNotFoundException implements Exception {
  final String message;

  const FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}
