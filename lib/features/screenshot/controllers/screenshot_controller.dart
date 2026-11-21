import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/text_recognition_service.dart';
import '../../results/views/results_view.dart';

class ScreenshotController extends GetxController {
  final ImagePicker _picker = ImagePicker();

  final TextRecognitionService _textService =
      TextRecognitionService();

  final Rxn<File> selectedImage = Rxn<File>();

  final RxBool isPicking = false.obs;
  final RxBool isProcessing = false.obs;

  static const String _permissionKey = 'photo_access_allowed';

  Future<void> pickScreenshot() async {
    if (isPicking.value) return;

    final prefs = await SharedPreferences.getInstance();

    // Check whether the user previously selected permanent Allow.
    final bool permanentlyAllowed =
        prefs.getBool(_permissionKey) ?? false;

    if (!permanentlyAllowed) {
      final permissionChoice = await _showPhotoPermissionDialog();

      if (permissionChoice == null || permissionChoice == 0) {
        return;
      }

      // Save permanent approval only when Allow is selected.
      if (permissionChoice == 2) {
        await prefs.setBool(_permissionKey, true);
      }
    }

    await _openGallery();
  }

  Future<int?> _showPhotoPermissionDialog() async {
    return await Get.dialog<int>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 65,
              width: 65,
              decoration: BoxDecoration(
                color: const Color(0xFF6254E8)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF6254E8),
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Allow Photo Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Screenshot to Action needs access to the screenshot '
              'you select so it can extract phone numbers, links, '
              'addresses, dates and text.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        actions: [
          // Allow permanently
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Get.back<int>(result: 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6254E8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Allow',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 5),

          // Allow only this time
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Get.back<int>(result: 1);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6254E8),
                side: const BorderSide(
                  color: Color(0xFF6254E8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Allow This Time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Not now
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Get.back<int>(result: 0);
              },
              child: const Text(
                'Not Now',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _openGallery() async {
    try {
      isPicking.value = true;

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        selectedImage.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to select screenshot.',
      );
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> analyzeScreenshot() async {
    final image = selectedImage.value;

    if (image == null) return;

    try {
      isProcessing.value = true;

      final result = await _textService.extractTextDetailed(
        image.path,
      );

      if (!result.hasAnyText) {
        Get.snackbar(
          'No Text Found',
          'We could not detect any readable English text in this image.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

     Get.to(() => ResultsView(
  extractedText: result.combinedText,
  recognitionResult: result,
  imagePath: image.path,
));
    } catch (e) {
      Get.snackbar(
        'Recognition Failed',
        'Unable to read text from this screenshot: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  void removeScreenshot() {
    selectedImage.value = null;
  }
}