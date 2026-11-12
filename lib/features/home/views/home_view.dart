import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../screenshot/controllers/screenshot_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ScreenshotController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screenshot to Action',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Make your screenshots useful.',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Extract information and turn it into actions '
                'with just one tap.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 35),

             Expanded(
  child: SingleChildScrollView(
    child: Center(
     
                  child: Obx(() {
                    final image = controller.selectedImage.value;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (image == null)
                            Container(
                              height: 90,
                              width: 90,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.document_scanner_outlined,
                                size: 45,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                image,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),

                          const SizedBox(height: 22),

                          Text(
                            image == null
                                ? 'Select a Screenshot'
                                : 'Screenshot Selected!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            image == null
                                ? 'Choose an image from your gallery '
                                    'to extract useful information.'
                                : 'Your screenshot is ready for analysis.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: controller.isPicking.value
                                  ? null
                                  : controller.pickScreenshot,
                              icon: controller.isPicking.value
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate,
                                    ),
                              label: Text(
                                controller.isPicking.value
                                    ? 'Selecting...'
                                    : image == null
                                        ? 'Choose Screenshot'
                                        : 'Choose Another',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

if (image != null) ...[
  const SizedBox(height: 15),

  SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: controller.isProcessing.value
          ? null
          : controller.analyzeScreenshot,
      icon: controller.isProcessing.value
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.document_scanner),

      label: Text(
        controller.isProcessing.value
            ? 'Analyzing Screenshot...'
            : 'Analyze Screenshot',
      ),

      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  ),
],
                          if (image != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: controller.removeScreenshot,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove Screenshot'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),
             ),
              const SizedBox(height: 15),

              const Center(
                child: Text(
                  'Your screenshots stay on your device.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        
        ),
      ),
    );
  }
}