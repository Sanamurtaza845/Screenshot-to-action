import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../services/text_recognition_service.dart';
import '../../results/views/results_view.dart';

class ScreenshotController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  final TextRecognitionService _textService =
      TextRecognitionService();

  final Rxn<File> selectedImage = Rxn<File>();

  final RxBool isPicking = false.obs;
  final RxBool isProcessing = false.obs;

  Future<void> pickScreenshot() async {
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

      final extractedText = await _textService.extractText(
        image.path,
      );

      if (extractedText.trim().isEmpty) {
        Get.snackbar(
          'No Text Found',
          'We could not detect any text in this image.',
        );
        return;
      }

      Get.to(
        () => ResultsView(
          extractedText: extractedText,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Recognition Failed',
        'Unable to read text from this screenshot.',
      );
    } finally {
      isProcessing.value = false;
    }
  }

  void removeScreenshot() {
    selectedImage.value = null;
  }
}