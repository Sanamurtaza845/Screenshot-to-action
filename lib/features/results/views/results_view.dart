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

    final phoneNumbers = detector.detectPhoneNumbers(extractedText);
    final websites = detector.detectWebsiteLinks(extractedText);
    final addresses = detector.detectAddresses(extractedText);
    final places = detector.detectPlaceCandidates(extractedText);

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
              const SizedBox(height: 6),
              const Text(
                'We extracted and formatted the information below.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    // RESTAURANTS, BRANDS & PLACES
                    if (places.isNotEmpty) ...[
                      _sectionTitle('Restaurants, Brands & Places'),
                      const SizedBox(height: 4),
                      const Text(
                        'Detected restaurants, stores, and brand names.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      ...places.map(
                        (place) => _ActionCard(
                          icon: Icons.storefront_outlined,
                          title: place,
                          subtitle: 'View location or search online',
                          buttonText: 'Maps',
                          onPressed: () {
                            final encoded = Uri.encodeComponent(place);
                            _launch('https://www.google.com/maps/search/?api=1&query=$encoded');
                          },
                          secondaryButtonText: 'Search',
                          onSecondaryPressed: () {
                            final encoded = Uri.encodeComponent(place);
                            _launch('https://www.google.com/search?q=$encoded');
                          },
                          onCopy: () => _copyToClipboard(place, 'Name copied to clipboard!'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ADDRESSES
                    if (addresses.isNotEmpty) ...[
                      _sectionTitle('Detected Addresses'),
                      const SizedBox(height: 4),
                      const Text(
                        'Street, house numbers, and full locations.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      ...addresses.map(
                        (address) => _ActionCard(
                          icon: Icons.location_on_outlined,
                          title: address,
                          subtitle: 'Open address in Google Maps',
                          buttonText: 'Maps',
                          onPressed: () {
                            final encoded = Uri.encodeComponent(address);
                            _launch('https://www.google.com/maps/search/?api=1&query=$encoded');
                          },
                          onCopy: () => _copyToClipboard(address, 'Address copied to clipboard!'),
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
                          subtitle: 'Open in web browser',
                          buttonText: 'Open',
                          onPressed: () {
                            final url = website.startsWith('http') ? website : 'https://$website';
                            _launch(url);
                          },
                          onCopy: () => _copyToClipboard(website, 'Link copied to clipboard!'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // PHONE NUMBERS
                    if (phoneNumbers.isNotEmpty) ...[
                      _sectionTitle('Phone Numbers'),
                      const SizedBox(height: 10),
                      ...phoneNumbers.map(
                        (number) => _ActionCard(
                          icon: Icons.phone_outlined,
                          title: number,
                          subtitle: 'Tap to call or dial',
                          buttonText: 'Call',
                          onPressed: () => _launch(
                            'tel:${number.replaceAll(RegExp(r'[^0-9+]'), '')}',
                          ),
                          onCopy: () => _copyToClipboard(number, 'Phone number copied to clipboard!'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // EXTRACTED TEXT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Extracted Text'),
                        TextButton.icon(
                          onPressed: () => _copyToClipboard(extractedText, 'Extracted text copied!'),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                          height: 1.6,
                          letterSpacing: 0.2,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // COPY ALL TEXT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(extractedText, 'All extracted text copied successfully.'),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy All Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied!',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(15),
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
          'No suitable app was found to open this link.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to perform this action.',
        snackPosition: SnackPosition.BOTTOM,
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
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onCopy;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
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
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
          if (secondaryButtonText != null && onSecondaryPressed != null)
            TextButton(
              onPressed: onSecondaryPressed,
              child: Text(secondaryButtonText!),
            ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
