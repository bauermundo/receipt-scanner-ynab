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

  // ── YNAB OAuth tokens ──────────────────────────────────────────────────────

  Future<void> saveYnabTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiresAt,
  }) async {
    try {
      await _secure.write(
          key: ApiConstants.keyYnabAccessToken, value: accessToken);
      if (refreshToken != null) {
        await _secure.write(
            key: ApiConstants.keyYnabRefreshToken, value: refreshToken);
      }
      await _prefs.setInt(ApiConstants.keyYnabTokenExpiresAt,
          expiresAt.millisecondsSinceEpoch);
    } catch (e) {
      throw StorageException('Failed to save YNAB tokens', e.toString());
    }
  }

  Future<String?> getYnabAccessToken() async {
    try {
      return await _secure.read(key: ApiConstants.keyYnabAccessToken);
    } catch (e) {
      throw StorageException('Failed to read YNAB access token', e.toString());
    }
  }

  Future<String?> getYnabRefreshToken() async {
    try {
      return await _secure.read(key: ApiConstants.keyYnabRefreshToken);
    } catch (e) {
      throw StorageException('Failed to read YNAB refresh token', e.toString());
    }
  }

  DateTime? getYnabTokenExpiresAt() {
    final ms = _prefs.getInt(ApiConstants.keyYnabTokenExpiresAt);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clearYnabTokens() async {
    try {
      await _secure.delete(key: ApiConstants.keyYnabAccessToken);
      await _secure.delete(key: ApiConstants.keyYnabRefreshToken);
      await _prefs.remove(ApiConstants.keyYnabTokenExpiresAt);
    } catch (e) {
      throw StorageException('Failed to clear YNAB tokens', e.toString());
    }
  }

  // ── Anthropic API key ──────────────────────────────────────────────────────

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
