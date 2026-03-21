import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/receipt/receipt_data.dart';

class ClaudeService {
  ClaudeService(this._client);

  final http.Client _client;

  static const _receiptPrompt = '''
Extract the receipt data from this image and return ONLY a valid JSON object
with exactly these fields:
{
  "merchant": "<store or restaurant name>",
  "date": "<ISO 8601 date, e.g. 2026-03-21>",
  "total": <total amount as a number, e.g. 25.50>,
  "items": [{"name": "<item name>", "amount": <item amount as number>}],
  "suggested_category": "<one of: Groceries, Dining Out, Shopping, Gas, Entertainment, Health, Transportation, Utilities, or Other>"
}
Do not include any explanation, markdown, or text outside the JSON object.
''';

  Future<ReceiptData> parseReceipt({
    required String apiKey,
    required File imageFile,
  }) async {
    final compressed = await _compressImage(imageFile);
    final base64Image = base64Encode(compressed);
    final mimeType = _detectMimeType(imageFile.path);

    final body = jsonEncode({
      'model': ApiConstants.claudeModel,
      'max_tokens': ApiConstants.claudeMaxTokens,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mimeType,
                'data': base64Image,
              },
            },
            {
              'type': 'text',
              'text': _receiptPrompt,
            },
          ],
        },
      ],
    });

    final response = await _client.post(
      Uri.parse('${ApiConstants.claudeBaseUrl}${ApiConstants.claudeMessagesEndpoint}'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': ApiConstants.anthropicVersion,
        'content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      final detail = response.body;
      if (response.statusCode == 401) {
        throw const ClaudeException(
            'Invalid Anthropic API key. Please check Settings.', 'HTTP 401');
      }
      if (response.statusCode == 429) {
        throw const ClaudeException(
            'Claude API rate limit reached. Please try again shortly.',
            'HTTP 429');
      }
      throw ClaudeException(
          'Failed to analyse receipt (${response.statusCode}).',
          'HTTP ${response.statusCode}: $detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (decoded['content'] as List).first;
    final rawText = content['text'] as String;

    return _parseReceiptJson(rawText);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<int>> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: ApiConstants.imageMaxDimension,
      minHeight: ApiConstants.imageMaxDimension,
      quality: ApiConstants.imageQuality,
      format: CompressFormat.jpeg,
    );
    if (result == null) {
      throw const ImageException(
          'Failed to compress image.', 'FlutterImageCompress returned null');
    }
    return result;
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  ReceiptData _parseReceiptJson(String rawText) {
    // Strip markdown fences if Claude wrapped the JSON
    final jsonString = _extractJson(rawText);
    if (jsonString == null) {
      throw ClaudeException(
          'Could not read receipt data from the image.',
          'No JSON found in Claude response: $rawText');
    }
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      // Normalise 'total' — Claude sometimes returns it as a string
      if (map['total'] is String) {
        map['total'] =
            double.tryParse((map['total'] as String).replaceAll(',', '')) ?? 0.0;
      }
      return ReceiptData.fromJson(map);
    } catch (e) {
      throw ClaudeException(
          'Could not read receipt data from the image.',
          'JSON parse error: $e | raw: $jsonString');
    }
  }

  String? _extractJson(String text) {
    // Already a bare JSON object
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) return trimmed;

    // Strip markdown fences: ```json ... ``` or ``` ... ```
    final fenceRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final fenceMatch = fenceRegex.firstMatch(text);
    if (fenceMatch != null) return fenceMatch.group(1)!.trim();

    // Find first { ... } block
    final braceRegex = RegExp(r'\{[\s\S]*\}');
    final braceMatch = braceRegex.firstMatch(text);
    return braceMatch?.group(0);
  }
}
