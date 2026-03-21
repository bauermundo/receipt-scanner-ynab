import 'dart:io';
import '../models/receipt/receipt_data.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../../core/errors/app_exception.dart';

class ReceiptRepository {
  ReceiptRepository(this._claudeService, this._storageService);

  final ClaudeService _claudeService;
  final StorageService _storageService;

  Future<ReceiptData> parseReceiptFromImage(File imageFile) async {
    final apiKey = await _storageService.getAnthropicApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const ClaudeException(
          'No Anthropic API key set. Please add it in Settings.',
          'Missing API key');
    }
    return _claudeService.parseReceipt(apiKey: apiKey, imageFile: imageFile);
  }
}
