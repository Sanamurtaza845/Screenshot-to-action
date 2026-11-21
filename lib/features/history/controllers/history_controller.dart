import 'dart:io';

import 'package:get/get.dart';

import '../models/history_item.dart';
import '../services/history_storage_service.dart';

class HistoryController extends GetxController {
  final HistoryStorageService _storageService =
      HistoryStorageService();

  final RxList<HistoryItem> historyItems = <HistoryItem>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  // Load saved History records.
  Future<void> loadHistory() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final items = await _storageService.getHistory();

      historyItems.assignAll(items);
    } catch (e) {
      errorMessage.value = 'Unable to load History.';
      print('History loading error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Save screenshot and its analysis results.
  Future<bool> saveHistory({
    required String imagePath,
    required String extractedText,
    required List<String> phoneNumbers,
    required List<String> websites,
    required List<String> addresses,
    required List<String> dates,
  }) async {
    if (isSaving.value) return false;

    String? savedImagePath;

    try {
      isSaving.value = true;
      errorMessage.value = null;

      final originalImage = File(imagePath);

      // Permanently save the original screenshot.
      savedImagePath = await _storageService.saveScreenshot(
        originalImage,
      );

      final item = HistoryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: savedImagePath,
        extractedText: extractedText,
        phoneNumbers: phoneNumbers,
        websites: websites,
        addresses: addresses,
        dates: dates,
        createdAt: DateTime.now(),
      );

      // Save the analysis record.
      await _storageService.saveHistoryItem(item);

      historyItems.insert(0, item);

      return true;
    } catch (e) {
      errorMessage.value = 'Unable to save this screenshot to History.';

      // Remove copied screenshot if saving the record failed.
      if (savedImagePath != null) {
        final savedFile = File(savedImagePath);

        if (await savedFile.exists()) {
          await savedFile.delete();
        }
      }

      print('History saving error: $e');

      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // Delete one History record.
  Future<void> deleteHistory(String id) async {
    try {
      await _storageService.deleteHistoryItem(id);

      historyItems.removeWhere(
        (item) => item.id == id,
      );
    } catch (e) {
      errorMessage.value = 'Unable to delete this History item.';
      print('History deletion error: $e');
    }
  }

  // Delete all History records.
  Future<void> clearAllHistory() async {
    try {
      isLoading.value = true;

      await _storageService.clearHistory();

      historyItems.clear();
      errorMessage.value = null;
    } catch (e) {
      errorMessage.value = 'Unable to clear History.';
      print('Clear History error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}