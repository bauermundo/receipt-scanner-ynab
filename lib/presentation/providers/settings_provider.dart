import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../data/models/receipt/receipt_data.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/claude_service.dart';
import '../../data/services/ynab_service.dart';
import '../../data/services/oauth_service.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../data/repositories/ynab_repository.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'Override sharedPreferencesProvider in ProviderScope');
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  return ClaudeService(ref.watch(httpClientProvider));
});

final ynabServiceProvider = Provider<YnabService>((ref) {
  return YnabService(ref.watch(httpClientProvider));
});

final oAuthServiceProvider = Provider<OAuthService>((ref) {
  return const OAuthService();
});

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository(
    ref.watch(claudeServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final ynabRepositoryProvider = Provider<YnabRepository>((ref) {
  return YnabRepository(
    ref.watch(ynabServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

// ── Settings state ─────────────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.ynabAccessToken,
    this.ynabRefreshToken,
    this.ynabTokenExpiresAt,
    this.anthropicApiKey,
    this.defaultBudgetId,
    this.defaultAccountId,
  });

  final String? ynabAccessToken;
  final String? ynabRefreshToken;
  final DateTime? ynabTokenExpiresAt;
  final String? anthropicApiKey;
  final String? defaultBudgetId;
  final String? defaultAccountId;

  bool get hasYnabToken =>
      ynabAccessToken != null && ynabAccessToken!.isNotEmpty;

  bool get isYnabTokenExpired =>
      ynabTokenExpiresAt != null &&
      DateTime.now().isAfter(ynabTokenExpiresAt!);

  bool get hasAnthropicKey =>
      anthropicApiKey != null && anthropicApiKey!.isNotEmpty;

  AppSettings copyWith({
    String? ynabAccessToken,
    String? ynabRefreshToken,
    DateTime? ynabTokenExpiresAt,
    String? anthropicApiKey,
    String? defaultBudgetId,
    String? defaultAccountId,
    bool clearYnab = false,
  }) {
    return AppSettings(
      ynabAccessToken: clearYnab ? null : (ynabAccessToken ?? this.ynabAccessToken),
      ynabRefreshToken: clearYnab ? null : (ynabRefreshToken ?? this.ynabRefreshToken),
      ynabTokenExpiresAt: clearYnab ? null : (ynabTokenExpiresAt ?? this.ynabTokenExpiresAt),
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      defaultBudgetId: defaultBudgetId ?? this.defaultBudgetId,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final storage = ref.watch(storageServiceProvider);
    String? accessToken;
    String? refreshToken;
    String? anthropicApiKey;
    try {
      accessToken = await storage.getYnabAccessToken();
      refreshToken = await storage.getYnabRefreshToken();
      anthropicApiKey = await storage.getAnthropicApiKey();
    } catch (_) {
      // Secure storage read failed — user will need to re-authenticate
    }
    return AppSettings(
      ynabAccessToken: accessToken,
      ynabRefreshToken: refreshToken,
      ynabTokenExpiresAt: storage.getYnabTokenExpiresAt(),
      anthropicApiKey: anthropicApiKey,
      defaultBudgetId: storage.getDefaultBudgetId(),
      defaultAccountId: storage.getDefaultAccountId(),
    );
  }

  /// Returns a valid access token, refreshing if expired.
  Future<String?> getValidAccessToken() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasYnabToken) return null;

    // Refresh proactively if within 5 minutes of expiry
    final expiresAt = current.ynabTokenExpiresAt;
    final needsRefresh = expiresAt == null ||
        DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

    if (!needsRefresh) return current.ynabAccessToken;

    final refreshToken = current.ynabRefreshToken;
    if (refreshToken == null) return current.ynabAccessToken;

    try {
      final tokens =
          await ref.read(oAuthServiceProvider).refresh(refreshToken);
      await saveYnabTokens(tokens);
      return tokens.accessToken;
    } catch (_) {
      // Refresh failed — return current token and let the API call fail
      return current.ynabAccessToken;
    }
  }

  Future<void> saveYnabTokens(OAuthTokens tokens) async {
    await ref.read(storageServiceProvider).saveYnabTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: tokens.expiresAt,
        );
    state = AsyncData(state.value!.copyWith(
      ynabAccessToken: tokens.accessToken,
      ynabRefreshToken: tokens.refreshToken ?? state.value?.ynabRefreshToken,
      ynabTokenExpiresAt: tokens.expiresAt,
    ));
    ref.invalidate(ynabBudgetsProvider);
  }

  Future<void> clearYnabTokens() async {
    await ref.read(storageServiceProvider).clearYnabTokens();
    state = AsyncData(state.value!.copyWith(clearYnab: true));
    ref.invalidate(ynabBudgetsProvider);
    ref.invalidate(ynabAccountsProvider);
    ref.invalidate(ynabCategoriesProvider);
    ref.invalidate(ynabPayeesProvider);
  }

  Future<void> saveAnthropicApiKey(String key) async {
    await ref.read(storageServiceProvider).saveAnthropicApiKey(key);
    state = AsyncData(state.value!.copyWith(anthropicApiKey: key));
  }

  Future<void> saveDefaultBudget(String budgetId) async {
    await ref.read(storageServiceProvider).saveDefaultBudgetId(budgetId);
    state = AsyncData(state.value!.copyWith(defaultBudgetId: budgetId));
    ref.invalidate(ynabAccountsProvider);
    ref.invalidate(ynabCategoriesProvider);
    ref.invalidate(ynabPayeesProvider);
  }

  Future<void> saveDefaultAccount(String accountId) async {
    await ref.read(storageServiceProvider).saveDefaultAccountId(accountId);
    state = AsyncData(state.value!.copyWith(defaultAccountId: accountId));
  }
}

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ── YNAB remote data ───────────────────────────────────────────────────────────

final ynabBudgetsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(ynabRepositoryProvider).getBudgets();
});

final ynabAccountsProvider =
    FutureProvider.autoDispose.family((ref, String budgetId) async {
  return ref.watch(ynabRepositoryProvider).getAccounts(budgetId);
});

final ynabCategoriesProvider =
    FutureProvider.autoDispose.family((ref, String budgetId) async {
  return ref.watch(ynabRepositoryProvider).getCategories(budgetId);
});

final ynabPayeesProvider =
    FutureProvider.autoDispose.family((ref, String budgetId) async {
  return ref.watch(ynabRepositoryProvider).getPayees(budgetId);
});

// ── Receipt state ──────────────────────────────────────────────────────────────

final currentReceiptProvider = StateProvider<ReceiptData?>((ref) => null);
