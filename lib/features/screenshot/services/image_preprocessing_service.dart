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

/// Service to preprocess screenshots before OCR:
/// - Resolution scaling (upscales low-res screenshots, normalizes excessively large images)
/// - Dark mode detection & automatic inversion (ensures dark text on light background)
/// - Grayscale conversion (eliminates chromatic noise & gradient artifacts)
/// - Contrast stretching & edge enhancement (boosts character recognition for both English and Urdu)
class ImagePreprocessingService {
  /// Preprocesses an image from [inputPath] to maximize OCR extraction accuracy.
  Future<PreprocessedImageResult> preprocess(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileNotFoundException('Screenshot file not found: $inputPath');
    }

    final bytes = await inputFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      // If decoding fails, return the original file as fallback
      return PreprocessedImageResult(
        file: inputFile,
        metadata: const PreprocessingMetadata(
          isDarkModeInverted: false,
          wasUpscaled: false,
          wasDownscaled: false,
          wasContrastEnhanced: false,
          originalWidth: 0,
          originalHeight: 0,
          processedWidth: 0,
          processedHeight: 0,
          averageLuminance: 128.0,
        ),
        isTemporary: false,
      );
    }

    final originalWidth = originalImage.width;
    final originalHeight = originalImage.height;

    img.Image workingImage = originalImage;

    // 1. RESOLUTION SCALING
    // OCR engines perform best when text height is 30-50 pixels.
    // Low resolution screenshots cause adjacent characters to merge.
    bool wasUpscaled = false;
    bool wasDownscaled = false;

    final minDimension = min(originalWidth, originalHeight);
    final maxDimension = max(originalWidth, originalHeight);

    if (minDimension < 1000) {
      // Upscale smaller screenshots by 1.5x - 2.0x
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
      // Downscale excessively large images to avoid out-of-memory crashes on mobile
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
    // OCR engines (ML Kit Latin & Tesseract) are heavily optimized for dark text on light backgrounds.
    // Dark mode screenshots (light text on black/dark background) suffer severe character dropouts.
    final avgLuminance = _calculateAverageLuminance(workingImage);
    bool isDarkModeInverted = false;

    if (avgLuminance < 115.0) {
      // Predominantly dark screenshot (dark mode) -> Invert colors
      workingImage = img.invert(workingImage);
      isDarkModeInverted = true;
    }

    // 3. GRAYSCALE CONVERSION
    // Eliminates background colored tinting, gradients, and compression chroma artifacts
    workingImage = img.grayscale(workingImage);

    // 4. CONTRAST ENHANCEMENT
    // Normalizes dynamic range so faded text pops with crisp character boundaries
    workingImage = img.contrast(workingImage, contrast: 135);
    const wasContrastEnhanced = true;

    // 5. ENCODE & SAVE OPTIMIZED PREPROCESSED IMAGE
    final processedBytes = img.encodePng(workingImage);
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFilePath =
        '${tempDir.path}/ocr_preprocessed_${timestamp}_${minDimension}.png';

    final tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(processedBytes, flush: true);

    final metadata = PreprocessingMetadata(
      isDarkModeInverted: isDarkModeInverted,
      wasUpscaled: wasUpscaled,
      wasDownscaled: wasDownscaled,
      wasContrastEnhanced: wasContrastEnhanced,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      processedWidth: workingImage.width,
      processedHeight: workingImage.height,
      averageLuminance: avgLuminance,
    );

    return PreprocessedImageResult(
      file: tempFile,
      metadata: metadata,
      isTemporary: true,
    );
  }

  /// Calculates the average luminance of an image using perceptual weights:
  /// Y = 0.299*R + 0.587*G + 0.114*B
  /// Uses a spatial stride for high performance.
  double _calculateAverageLuminance(img.Image image) {
    double total = 0;
    int samples = 0;

    // Sample at most ~10,000 points across the image for fast execution
    final stepX = max(1, (image.width / 100).round());
    final stepY = max(1, (image.height / 100).round());

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final pixel = image.getPixel(x, y);
        final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        total += lum;
        samples++;
      }
    }

    return samples > 0 ? (total / samples) : 128.0;
  }
}

class FileNotFoundException implements Exception {
  final String message;
  const FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}
