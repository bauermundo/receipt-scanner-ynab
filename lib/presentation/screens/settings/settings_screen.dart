import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/ynab/ynab_budget.dart';
import '../../../data/models/ynab/ynab_account.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ynabTokenCtrl;
  late TextEditingController _anthropicKeyCtrl;
  bool _obscureYnab = true;
  bool _obscureAnthropic = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ynabTokenCtrl = TextEditingController();
    _anthropicKeyCtrl = TextEditingController();
    // Populate once settings finish loading (may already be ready)
    ref.listenManual(settingsNotifierProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null) {
        if (_ynabTokenCtrl.text.isEmpty) {
          _ynabTokenCtrl.text = s.ynabToken ?? '';
        }
        if (_anthropicKeyCtrl.text.isEmpty) {
          _anthropicKeyCtrl.text = s.anthropicApiKey ?? '';
        }
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _ynabTokenCtrl.dispose();
    _anthropicKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(settingsNotifierProvider.notifier);
      await notifier.saveYnabToken(_ynabTokenCtrl.text.trim());
      await notifier.saveAnthropicApiKey(_anthropicKeyCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── API Keys ────────────────────────────────────────────────
                Text('API Keys',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ynabTokenCtrl,
                  obscureText: _obscureYnab,
                  decoration: InputDecoration(
                    labelText: 'YNAB Personal Access Token',
                    hintText: 'Paste your token from app.ynab.com',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureYnab
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureYnab = !_obscureYnab),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _anthropicKeyCtrl,
                  obscureText: _obscureAnthropic,
                  decoration: InputDecoration(
                    labelText: 'Anthropic API Key',
                    hintText: 'sk-ant-...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureAnthropic
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _obscureAnthropic = !_obscureAnthropic),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save API Keys'),
                ),

                const Divider(height: 40),

                // ── Default Budget & Account ─────────────────────────────────
                Text('Defaults',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Select your default budget and account for new transactions.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),

                if (settings?.hasYnabToken == true) ...[
                  _BudgetDropdown(currentSettings: settings!),
                  const SizedBox(height: 12),
                  if (settings.defaultBudgetId != null)
                    _AccountDropdown(
                        budgetId: settings.defaultBudgetId!,
                        currentSettings: settings),
                ] else
                  const Text(
                    'Save your YNAB token above to select a budget and account.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetDropdown extends ConsumerWidget {
  const _BudgetDropdown({required this.currentSettings});
  final AppSettings currentSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(ynabBudgetsProvider);
    return budgetsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load budgets: $e',
          style: const TextStyle(color: Colors.red)),
      data: (budgets) {
        final list = budgets as List<YnabBudget>;
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Default Budget'),
          isExpanded: true,
          value: list.any((b) => b.id == currentSettings.defaultBudgetId)
              ? currentSettings.defaultBudgetId
              : null,
          items: list
              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
              .toList(),
          onChanged: (id) {
            if (id != null) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .saveDefaultBudget(id);
            }
          },
        );
      },
    );
  }
}

class _AccountDropdown extends ConsumerWidget {
  const _AccountDropdown(
      {required this.budgetId, required this.currentSettings});
  final String budgetId;
  final AppSettings currentSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(ynabAccountsProvider(budgetId));
    return accountsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load accounts: $e',
          style: const TextStyle(color: Colors.red)),
      data: (accounts) {
        final list = accounts as List<YnabAccount>;
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Default Account'),
          isExpanded: true,
          value: list.any((a) => a.id == currentSettings.defaultAccountId)
              ? currentSettings.defaultAccountId
              : null,
          items: list
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (id) {
            if (id != null) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .saveDefaultAccount(id);
            }
          },
        );
      },
    );
  }
}
