import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/ynab/ynab_budget.dart';
import '../../../data/models/ynab/ynab_account.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _anthropicKeyCtrl;
  bool _obscureAnthropic = true;
  bool _savingKey = false;
  bool _connectingYnab = false;

  @override
  void initState() {
    super.initState();
    _anthropicKeyCtrl = TextEditingController();
    ref.listenManual(settingsNotifierProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null && _anthropicKeyCtrl.text.isEmpty) {
        _anthropicKeyCtrl.text = s.anthropicApiKey ?? '';
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _anthropicKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectYnab() async {
    setState(() => _connectingYnab = true);
    try {
      final oAuth = ref.read(oAuthServiceProvider);
      final tokens = await oAuth.authorize();
      await ref.read(settingsNotifierProvider.notifier).saveYnabTokens(tokens);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('YNAB connected!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect to YNAB: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingYnab = false);
    }
  }

  Future<void> _disconnectYnab() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect YNAB?'),
        content: const Text(
            'You will need to reconnect to create transactions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsNotifierProvider.notifier).clearYnabTokens();
    }
  }

  Future<void> _saveAnthropicKey() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingKey = true);
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .saveAnthropicApiKey(_anthropicKeyCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.valueOrNull;
    final isConnected = settings?.hasYnabToken == true;

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
                // ── YNAB Connection ─────────────────────────────────────────
                Text('YNAB',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                if (isConnected) ...[
                  // Connected state
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade700),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.shade900.withOpacity(0.2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade400, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connected to YNAB',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.green.shade300),
                          ),
                        ),
                        TextButton(
                          onPressed: _disconnectYnab,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade300),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Not connected state
                  OutlinedButton.icon(
                    onPressed: _connectingYnab ? null : _connectYnab,
                    icon: _connectingYnab
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Connect YNAB Account'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Opens YNAB in your browser to authorise this app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],

                const Divider(height: 40),

                // ── Anthropic API Key ────────────────────────────────────────
                Text('Claude AI',
                    style: Theme.of(context).textTheme.titleMedium),
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
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _savingKey ? null : _saveAnthropicKey,
                  child: _savingKey
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save API Key'),
                ),

                const Divider(height: 40),

                // ── Default Budget & Account ──────────────────────────────────
                Text('Defaults',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Select your default budget and account for new transactions.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),

                if (isConnected) ...[
                  _BudgetDropdown(currentSettings: settings!),
                  const SizedBox(height: 12),
                  if (settings.defaultBudgetId != null)
                    _AccountDropdown(
                        budgetId: settings.defaultBudgetId!,
                        currentSettings: settings),
                ] else
                  const Text(
                    'Connect YNAB above to select a budget and account.',
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
