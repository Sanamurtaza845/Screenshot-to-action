import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../screenshot/services/action_detection_service.dart';

class ResultsView extends StatelessWidget {
  final String extractedText;

  const ResultsView({
    super.key,
    required this.extractedText,
  });

  @override
  Widget build(BuildContext context) {
    final detector = ActionDetectionService();

    final phoneNumbers =
        detector.detectPhoneNumbers(extractedText);

    final websites =
        detector.detectWebsiteLinks(extractedText);

    final addresses =
        detector.detectAddresses(extractedText);

    final places =
        detector.detectPlaceCandidates(extractedText);

        debugPrint('EXTRACTED TEXT: $extractedText');
debugPrint('DETECTED PLACES: $places');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screenshot Results',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your screenshot is ready!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'We found the following information.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [

                    // PHONE NUMBERS
                    if (phoneNumbers.isNotEmpty) ...[
                      _sectionTitle('Phone Numbers'),

                      const SizedBox(height: 10),

                      ...phoneNumbers.map(
                        (number) => _ActionCard(
                          icon: Icons.phone,
                          title: number,
                          subtitle: 'Tap to call',
                          buttonText: 'Call',
                          onPressed: () => _launch(
                            'tel:${number.replaceAll(RegExp(r'[^0-9+]'), '')}',
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],

                    // WEBSITES
                    if (websites.isNotEmpty) ...[
                      _sectionTitle('Website Links'),

                      const SizedBox(height: 10),

                      ...websites.map(
                        (website) => _ActionCard(
                          icon: Icons.language,
                          title: website,
                          subtitle: 'Open website',
                          buttonText: 'Open',
                          onPressed: () {
                            final url = website.startsWith('http')
                                ? website
                                : 'https://$website';

                            _launch(url);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],

                    // AUTOMATIC PLACE DETECTION
                    if (places.isNotEmpty) ...[
                      _sectionTitle('Detected Places & Businesses'),

                      const SizedBox(height: 5),

                      const Text(
                        'We found these possible places in your screenshot.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...places.map(
                        (place) => _ActionCard(
                          icon: Icons.storefront,
                          title: place,
                          subtitle: 'Search this place on Google Maps',
                          buttonText: 'Maps',
                          onPressed: () {
                            final encodedPlace =
                                Uri.encodeComponent(place);

                            _launch(
                              'https://www.google.com/maps/search/?api=1&query=$encodedPlace',
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],

                    // ADDRESS DETECTION
                    if (addresses.isNotEmpty) ...[
                      _sectionTitle('Detected Addresses'),

                      const SizedBox(height: 10),

                      ...addresses.map(
                        (address) => _ActionCard(
                          icon: Icons.location_on_outlined,
                          title: address,
                          subtitle: 'Open address in Google Maps',
                          buttonText: 'Maps',
                          onPressed: () {
                            final encodedAddress =
                                Uri.encodeComponent(address);

                            _launch(
                              'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],

                    // EXTRACTED TEXT
                    _sectionTitle('Extracted Text'),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: SelectableText(
                        extractedText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.8,
                          letterSpacing: 0.2,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // COPY ALL TEXT
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: extractedText),
                    );

                    Get.snackbar(
                      'Copied!',
                      'Extracted text copied successfully.',
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy All Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _launch(String value) async {
    final uri = Uri.parse(value);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        Get.snackbar(
          'Unable to Open',
          'No suitable app was found.',
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to perform this action.',
      );
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 25,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}