import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../data/models/receipt/receipt_data.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/claude_service.dart';
import '../../data/services/ynab_service.dart';
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
    this.ynabToken,
    this.anthropicApiKey,
    this.defaultBudgetId,
    this.defaultAccountId,
  });

  final String? ynabToken;
  final String? anthropicApiKey;
  final String? defaultBudgetId;
  final String? defaultAccountId;

  bool get hasYnabToken => ynabToken != null && ynabToken!.isNotEmpty;
  bool get hasAnthropicKey =>
      anthropicApiKey != null && anthropicApiKey!.isNotEmpty;

  AppSettings copyWith({
    String? ynabToken,
    String? anthropicApiKey,
    String? defaultBudgetId,
    String? defaultAccountId,
  }) {
    return AppSettings(
      ynabToken: ynabToken ?? this.ynabToken,
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
    // Catch storage errors (e.g. Android Keystore issues) so the app
    // always starts rather than getting stuck in AsyncError state.
    String? ynabToken;
    String? anthropicApiKey;
    try {
      ynabToken = await storage.getYnabToken();
      anthropicApiKey = await storage.getAnthropicApiKey();
    } catch (_) {
      // Keys unreadable — user will need to re-enter in Settings
    }
    return AppSettings(
      ynabToken: ynabToken,
      anthropicApiKey: anthropicApiKey,
      defaultBudgetId: storage.getDefaultBudgetId(),
      defaultAccountId: storage.getDefaultAccountId(),
    );
  }

  Future<void> saveYnabToken(String token) async {
    await ref.read(storageServiceProvider).saveYnabToken(token);
    state = AsyncData(state.value!.copyWith(ynabToken: token));
    ref.invalidate(ynabBudgetsProvider);
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
