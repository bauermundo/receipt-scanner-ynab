import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';

class StorageService {
  StorageService(this._prefs)
      : _secure = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  // ── Secure (API keys) ──────────────────────────────────────────────────────

  Future<void> saveYnabToken(String token) async {
    try {
      await _secure.write(key: ApiConstants.keyYnabToken, value: token);
    } catch (e) {
      throw StorageException('Failed to save YNAB token', e.toString());
    }
  }

  Future<String?> getYnabToken() async {
    try {
      return await _secure.read(key: ApiConstants.keyYnabToken);
    } catch (e) {
      throw StorageException('Failed to read YNAB token', e.toString());
    }
  }

  Future<void> saveAnthropicApiKey(String key) async {
    try {
      await _secure.write(key: ApiConstants.keyAnthropicApiKey, value: key);
    } catch (e) {
      throw StorageException('Failed to save Anthropic API key', e.toString());
    }
  }

  Future<String?> getAnthropicApiKey() async {
    try {
      return await _secure.read(key: ApiConstants.keyAnthropicApiKey);
    } catch (e) {
      throw StorageException(
          'Failed to read Anthropic API key', e.toString());
    }
  }

  // ── Non-sensitive (budget / account selection) ─────────────────────────────

  String? getDefaultBudgetId() =>
      _prefs.getString(ApiConstants.keyDefaultBudgetId);

  Future<void> saveDefaultBudgetId(String id) =>
      _prefs.setString(ApiConstants.keyDefaultBudgetId, id);

  String? getDefaultAccountId() =>
      _prefs.getString(ApiConstants.keyDefaultAccountId);

  Future<void> saveDefaultAccountId(String id) =>
      _prefs.setString(ApiConstants.keyDefaultAccountId, id);

  Future<void> clearAll() async {
    await _secure.deleteAll();
    await _prefs.clear();
  }
}
