import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_item.dart';

class HistoryStorageService {
  static const String _historyKey = 'screenshot_history';

  Future<Directory> _getHistoryDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();

    final historyDirectory = Directory(
      '${appDirectory.path}/ScreenshotHistory',
    );

    if (!await historyDirectory.exists()) {
      await historyDirectory.create(recursive: true);
    }

    return historyDirectory;
  }

  // Save original screenshot permanently.
  Future<String> saveScreenshot(File image) async {
    if (!await image.exists()) {
      throw Exception('Original screenshot file does not exist.');
    }

    final directory = await _getHistoryDirectory();

    final extension = image.path.contains('.')
        ? image.path.substring(image.path.lastIndexOf('.'))
        : '.jpg';

    final fileName =
        'screenshot_${DateTime.now().microsecondsSinceEpoch}$extension';

    final savedImage = await image.copy(
      '${directory.path}/$fileName',
    );

    return savedImage.path;
  }

  // Save a History record.
  Future<void> saveHistoryItem(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();

    final history = await getHistory();

    history.insert(0, item);

    final encodedHistory = jsonEncode(
      history.map((item) => item.toMap()).toList(),
    );

    final success = await prefs.setString(
      _historyKey,
      encodedHistory,
    );

    if (!success) {
      throw Exception('Unable to save History record.');
    }
  }

  // Load all History records.
  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final storedData = prefs.getString(_historyKey);

    if (storedData == null || storedData.isEmpty) {
      return [];
    }

    final List<dynamic> decodedData = jsonDecode(storedData);

    final items = decodedData.map((item) {
      return HistoryItem.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList();

    return items.where((item) {
      return File(item.imagePath).existsSync();
    }).toList();
  }

  // Delete a History record and its screenshot.
  Future<void> deleteHistoryItem(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final history = await getHistory();

    final item = history.firstWhere(
      (item) => item.id == id,
    );

    final imageFile = File(item.imagePath);

    if (await imageFile.exists()) {
      await imageFile.delete();
    }

    history.removeWhere((item) => item.id == id);

    await prefs.setString(
      _historyKey,
      jsonEncode(
        history.map((item) => item.toMap()).toList(),
      ),
    );
  }

  // Clear all History records and screenshots.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final history = await getHistory();

    for (final item in history) {
      final imageFile = File(item.imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    }

    await prefs.remove(_historyKey);
  }
}