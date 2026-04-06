import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/receipt/receipt_data.dart';
import '../models/ynab/ynab_category.dart';

class ClaudeService {
  ClaudeService(this._client);

  final http.Client _client;

  static String _buildPrompt(List<YnabCategory>? categories) {
    final categorySection = categories != null && categories.isNotEmpty
        ? '''
Available YNAB budget categories (use these exact IDs in suggested_category_id):
${categories.map((c) => '  ${c.id} → ${c.categoryGroupName}: ${c.name}').join('\n')}

'''
        : '';

    final itemCategoryFields = categories != null
        ? '''
      "suggested_category_id": "<ID from the list above that best fits this item, or null>",
      "suggested_category_name": "<matching category name, or null>"'''
        : '''
      "suggested_category_id": null,
      "suggested_category_name": null''';

    return '''
${categorySection}Extract the receipt data from this image and return ONLY a valid JSON object with exactly these fields:
{
  "merchant": "<store or restaurant name>",
  "date": "<ISO 8601 date, e.g. 2026-03-21>",
  "total": <total amount as a number, e.g. 25.50>,
  "payment_method": "<card type and last 4 digits visible on receipt, e.g. 'Visa 2902' or 'Mastercard 1234', or null if not visible>",
  "memo": "<if 5 or fewer items: comma-separated item names, e.g. 'Milk, Eggs, Tide Pods'. If more than 5 items: a concise 1-sentence summary of what was purchased, e.g. 'Weekly grocery run — produce, dairy, cleaning supplies, and snacks'. Max 100 characters.>",
  "items": [
    {
      "name": "<item name>",
      "amount": <item amount as number>,
$itemCategoryFields
    }
  ],
  "suggested_category": "<best overall category name for this receipt>"
}
Do not include any explanation, markdown, or text outside the JSON object.
''';
  }

  Future<ReceiptData> parseReceipt({
    required String apiKey,
    required File imageFile,
    List<YnabCategory>? ynabCategories,
  }) async {
    final compressed = await _compressImage(imageFile);
    final base64Image = base64Encode(compressed);
    final mimeType = _detectMimeType(imageFile.path);
    final prompt = _buildPrompt(ynabCategories);

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
              'text': prompt,
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
      // Normalise item amounts
      if (map['items'] is List) {
        for (final item in map['items'] as List) {
          if (item is Map<String, dynamic> && item['amount'] is String) {
            item['amount'] =
                double.tryParse((item['amount'] as String).replaceAll(',', '')) ?? 0.0;
          }
        }
      }
      return ReceiptData.fromJson(map);
    } catch (e) {
      throw ClaudeException(
          'Could not read receipt data from the image.',
          'JSON parse error: $e | raw: $jsonString');
    }
  }

  String? _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) return trimmed;

    final fenceRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final fenceMatch = fenceRegex.firstMatch(text);
    if (fenceMatch != null) return fenceMatch.group(1)!.trim();

    final braceRegex = RegExp(r'\{[\s\S]*\}');
    final braceMatch = braceRegex.firstMatch(text);
    return braceMatch?.group(0);
  }
}
