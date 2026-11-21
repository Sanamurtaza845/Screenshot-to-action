import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../screenshot/services/action_detection_service.dart';
import '../../screenshot/services/image_preprocessing_service.dart';
import '../../screenshot/services/text_recognition_service.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class ResultsView extends StatelessWidget {
  final String extractedText;
  final RecognitionResult? recognitionResult;

  ResultsView({
    super.key,
    required this.extractedText,
    this.recognitionResult,
  });

  final ActionDetectionService _detector = ActionDetectionService();

  static const Color _background = Color(0xFFF6F8FC);
  static const Color _text = Color(0xFF172033);
  static const Color _muted = Color(0xFF7B8495);

  @override
  Widget build(BuildContext context) {
    final phones = _detector.detectPhoneNumbers(extractedText);
    final websites = _detector.detectWebsiteLinks(extractedText);
    final addresses = _detector.detectAddresses(extractedText);
    final dates = _detector.detectDatesAndEvents(extractedText);

    final totalDetected =
        phones.length + websites.length + addresses.length + dates.length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Screenshot Results',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        iconTheme: const IconThemeData(color: _text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                children: [
                  _buildHeader(totalDetected),

                  if (recognitionResult?.engineNotice != null) ...[
                    const SizedBox(height: 14),
                    _buildEngineNoticeBadge(
                      recognitionResult!.engineNotice!,
                      isGemini: recognitionResult!.isGeminiVision,
                    ),
                  ],

                  if (recognitionResult?.preprocessingMetadata != null) ...[
                    const SizedBox(height: 14),
                    _buildPreprocessingBadge(recognitionResult!.preprocessingMetadata!),
                  ],

                  const SizedBox(height: 22),

                  _buildSection(
                    title: 'Phone Numbers',
                    subtitle: 'Numbers found in your screenshot',
                    icon: Icons.phone_outlined,
                    color: const Color(0xFF168B67),
                    count: phones.length,
                    child: phones.isEmpty
                        ? _emptyMessage('No phone numbers detected.')
                        : Column(
                            children: phones
                                .map(
                                  (phone) => _buildActionCard(
                                    icon: Icons.phone,
                                    title: phone,
                                    subtitle: 'Phone number',
                                    color: const Color(0xFF168B67),
                                    actions: [
                                      _actionButton(
                                        label: 'Call',
                                        icon: Icons.call,
                                        primary: true,
                                        onPressed: () => _launch(
                                          context,
                                          'tel:$phone',
                                        ),
                                      ),
                                      _actionButton(
                                        label: 'Copy',
                                        icon: Icons.copy,
                                        onPressed: () => _copy(
                                          context,
                                          phone,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                  ),

                  _buildSection(
                    title: 'Website Links',
                    subtitle: 'Websites you can open directly',
                    icon: Icons.language,
                    color: const Color(0xFF3978D4),
                    count: websites.length,
                    child: websites.isEmpty
                        ? _emptyMessage('No website links detected.')
                        : Column(
                            children: websites
                                .map(
                                  (website) => _buildActionCard(
                                    icon: Icons.public,
                                    title: website,
                                    subtitle: 'Website link',
                                    color: const Color(0xFF3978D4),
                                    actions: [
                                      _actionButton(
                                        label: 'Open',
                                        icon: Icons.open_in_new,
                                        primary: true,
                                        onPressed: () => _launch(
                                          context,
                                          website,
                                        ),
                                      ),
                                      _actionButton(
                                        label: 'Copy',
                                        icon: Icons.copy,
                                        onPressed: () => _copy(
                                          context,
                                          website,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                  ),

                  _buildSection(
                    title: 'Addresses',
                    subtitle: 'Locations identified in your screenshot',
                    icon: Icons.location_on_outlined,
                    color: const Color(0xFFE28A32),
                    count: addresses.length,
                    child: addresses.isEmpty
                        ? _emptyMessage('No addresses detected.')
                        : Column(
                            children: addresses
                                .map(
                                  (address) => _buildActionCard(
                                    icon: Icons.location_on_outlined,
                                    title: address,
                                    subtitle: 'Detected location',
                                    color: const Color(0xFFE28A32),
                                    actions: [
                                      _actionButton(
                                        label: 'Maps',
                                        icon: Icons.map_outlined,
                                        primary: true,
                                        onPressed: () => _launch(
                                          context,
                                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                                        ),
                                      ),
                                      _actionButton(
                                        label: 'Copy',
                                        icon: Icons.copy,
                                        onPressed: () => _copy(
                                          context,
                                          address,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                  ),

_buildSection(
  title: 'Dates & Events',
  subtitle: 'Dates and related text found',
  icon: Icons.calendar_month_outlined,
  color: const Color(0xFF895CC5),
  count: dates.length,
  child: dates.isEmpty
      ? _emptyMessage('No dates detected.')
      : Column(
          children: dates.map((date) {
            return _buildActionCard(
              icon: Icons.event_outlined,
              title: date,
              subtitle: 'Detected date',
              color: const Color(0xFF895CC5),
              actions: [
                _actionButton(
                  label: 'Set Date & Event',
                  icon: Icons.calendar_month,
                  primary: true,
                  onPressed: () {
                    _showCalendarEventDialog(context, date);
                  },
                ),
                _actionButton(
                  label: 'Copy',
                  icon: Icons.copy,
                  onPressed: () => _copy(context, date),
                ),
              ],
            );
          }).toList(),
        ),
),
_buildSection(
                    title: 'Extracted Text',
                    subtitle: 'All readable text from your screenshot',
                    icon: Icons.text_snippet_outlined,
                    color: const Color(0xFF52647D),
                    child: _buildExtractedText(context),
                  ),
                ],
              ),
            ),

            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }
Future<void> _showCalendarEventDialog(
  BuildContext context,
  String detectedText,
) async {
  final titleController = TextEditingController(
    text: 'Event - $detectedText',
  );

DateTime selectedDate = _parseDetectedDate(detectedText);
  TimeOfDay selectedTime = TimeOfDay.now();

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Create Calendar Event',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Title',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter event title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Select Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Select Time',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedTime,
                      );

                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(selectedTime.format(context)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result != true) {
    titleController.dispose();
    return;
  }

  final startDate = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedTime.hour,
    selectedTime.minute,
  );

  final event = Event(
    title: titleController.text.trim(),
    description: 'Created using Screenshot to Action.',
    startDate: startDate,
    endDate: startDate.add(const Duration(hours: 1)),
    allDay: false,
  );

  titleController.dispose();

  try {
    final success = await Add2Calendar.addEvent2Cal(event);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Calendar event opened successfully!'
              : 'Unable to open the calendar.',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the calendar.'),
      ),
    );
  }
}
DateTime _parseDetectedDate(String text) {
  final now = DateTime.now();
  final normalized = _detector.normalizeUrduDigits(text);

  const months = {
    'january': 1, 'jan': 1, 'جنوری': 1,
    'february': 2, 'feb': 2, 'فروری': 2,
    'march': 3, 'mar': 3, 'مارچ': 3,
    'april': 4, 'apr': 4, 'اپریل': 4,
    'may': 5, 'مئی': 5,
    'june': 6, 'jun': 6, 'جون': 6,
    'july': 7, 'jul': 7, 'جولائی': 7,
    'august': 8, 'aug': 8, 'اگست': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'ستمبر': 9,
    'october': 10, 'oct': 10, 'اکتوبر': 10,
    'november': 11, 'nov': 11, 'نومبر': 11,
    'december': 12, 'dec': 12, 'دسمبر': 12,
  };

  final monthPattern = months.keys.join('|');

  final monthFirst = RegExp(
    '($monthPattern)\\s+(\\d{1,2})(?:st|nd|rd|th)?'
    '(?:,?\\s+(\\d{4}))?',
    caseSensitive: false,
  );

  final dayFirst = RegExp(
    '(\\d{1,2})(?:st|nd|rd|th)?\\s+'
    '($monthPattern)(?:,?\\s+(\\d{4}))?',
    caseSensitive: false,
  );

  final numeric = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
  );

  final iso = RegExp(
    r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
  );

  int year = now.year;
  int month = now.month;
  int day = now.day;

  final isoMatch = iso.firstMatch(normalized);

  if (isoMatch != null) {
    year = int.parse(isoMatch.group(1)!);
    month = int.parse(isoMatch.group(2)!);
    day = int.parse(isoMatch.group(3)!);
  } else {
    final numericMatch = numeric.firstMatch(normalized);

    if (numericMatch != null) {
      day = int.parse(numericMatch.group(1)!);
      month = int.parse(numericMatch.group(2)!);
      year = int.parse(numericMatch.group(3)!);

      if (year < 100) {
        year += 2000;
      }
    } else {
      final match = dayFirst.firstMatch(normalized) ??
          monthFirst.firstMatch(normalized);

      if (match == null) return now;

      final isDayFirst = dayFirst.firstMatch(normalized) != null;

      if (isDayFirst) {
        day = int.parse(match.group(1)!);
        month = months[match.group(2)!.toLowerCase()]!;
      } else {
        month = months[match.group(1)!.toLowerCase()]!;
        day = int.parse(match.group(2)!);
      }

      final yearText = match.group(3);

      if (yearText != null) {
        year = int.parse(yearText);
      }
    }
  }

  try {
    final parsed = DateTime(year, month, day);

    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return now;
    }

    return parsed;
  } catch (_) {
    return now;
  }
}
  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------

  Widget _buildHeader(int totalDetected) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$totalDetected items detected in your screenshot',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ready to use',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SECTION
  // --------------------------------------------------

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
    int? count,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 17),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEDF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
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
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count found',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ACTION CARD
  // --------------------------------------------------

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Widget> actions,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: actions),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ACTION BUTTON
  // --------------------------------------------------

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 7),
        child: SizedBox(
          height: 38,
          child: primary
              ? ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 15),
                  label: Text(label),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 15),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    side: const BorderSide(color: Color(0xFFDDE2EA)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------

  Widget _emptyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: _muted,
            size: 27,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineNoticeBadge(String notice, {required bool isGemini}) {
    final color = isGemini ? const Color(0xFF6254E8) : const Color(0xFF455A64);
    final bgColor = isGemini
        ? const Color(0xFF6254E8).withValues(alpha: 0.08)
        : const Color(0xFF455A64).withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGemini ? Icons.auto_awesome : Icons.offline_bolt_outlined,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              notice,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreprocessingBadge(PreprocessingMetadata metadata) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6254E8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6254E8).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_fix_high_rounded,
            color: Color(0xFF6254E8),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Image Preprocessed: ${metadata.summary}',
              style: const TextStyle(
                color: Color(0xFF322E73),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // EXTRACTED TEXT
  // --------------------------------------------------

  Widget _buildExtractedText(BuildContext context) {
    final isPureUrdu =
        _isUrdu(extractedText) && !RegExp(r'[a-zA-Z]').hasMatch(extractedText);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6254E8).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.text_snippet_rounded,
                      size: 14,
                      color: Color(0xFF6254E8),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Extracted Text (As in Image)',
                      style: TextStyle(
                        color: Color(0xFF6254E8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: extractedText.isEmpty
                    ? null
                    : () => _copy(context, extractedText),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            extractedText.isEmpty
                ? 'No text could be extracted from this screenshot.'
                : extractedText,
            textDirection:
                isPureUrdu ? TextDirection.rtl : TextDirection.ltr,
            textAlign: isPureUrdu ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: _text,
              fontSize: 15,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  bool _isUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);
  }

  // --------------------------------------------------
  // BOTTOM BUTTON
  // --------------------------------------------------

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: extractedText.isEmpty
              ? null
              : () => _copy(context, extractedText),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text(
            'Copy All Extracted Text',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // COPY
  // --------------------------------------------------

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --------------------------------------------------
  // OPEN LINKS / CALL
  // --------------------------------------------------

  Future<void> _launch(BuildContext context, String value) async {
    try {
      final uri = Uri.parse(value);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this item.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while opening this item.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
