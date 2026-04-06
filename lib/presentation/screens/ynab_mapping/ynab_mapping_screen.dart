import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/receipt/receipt_data.dart';
import '../../../data/models/receipt/receipt_item.dart';
import '../../../data/models/ynab/ynab_account.dart';
import '../../../data/models/ynab/ynab_category.dart';
import '../../../data/models/ynab/ynab_payee.dart';
import '../../../data/models/ynab/ynab_transaction_request.dart';

class YnabMappingScreen extends ConsumerStatefulWidget {
  const YnabMappingScreen({super.key});

  @override
  ConsumerState<YnabMappingScreen> createState() => _YnabMappingScreenState();
}

class _YnabMappingScreenState extends ConsumerState<YnabMappingScreen> {
  String? _selectedAccountId;
  String? _selectedCategoryId;

  /// Either a known payee ID (from dropdown) or null when using custom name.
  String? _selectedPayeeId;

  /// Used when the user types a new payee name not in YNAB.
  late TextEditingController _payeeNameCtrl;

  bool _useCustomPayee = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final receipt = ref.read(currentReceiptProvider);
    _payeeNameCtrl = TextEditingController(text: receipt?.merchant ?? '');

    // Pre-fill account from settings default
    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    _selectedAccountId = settings?.defaultAccountId;
  }

  @override
  void dispose() {
    _payeeNameCtrl.dispose();
    super.dispose();
  }

  /// Auto-detect account from card digits in paymentMethod (e.g. "Visa 2902").
  String? _detectAccountId(
      String? paymentMethod, List<YnabAccount> accounts) {
    if (paymentMethod == null) return null;
    final digits = RegExp(r'\d{4}').allMatches(paymentMethod).lastOrNull?.group(0);
    if (digits == null) return null;
    final matches = accounts.where((a) => a.name.contains(digits)).toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  Future<void> _submit() async {
    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    final budgetId = settings?.defaultBudgetId;
    final receipt = ref.read(currentReceiptProvider);

    if (budgetId == null) {
      setState(() => _error = 'Please select a default budget in Settings.');
      return;
    }
    if (_selectedAccountId == null) {
      setState(() => _error = 'Please select an account.');
      return;
    }
    if (receipt == null) {
      setState(() => _error = 'No receipt data found.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Build subtransactions if items have per-item categories
      final categorizedItems = receipt.items
          .where((i) => i.suggestedCategoryId != null && i.amount > 0)
          .toList();

      final List<YnabSubtransaction>? subtransactions;
      if (categorizedItems.length > 1) {
        subtransactions = categorizedItems
            .map((i) => YnabSubtransaction(
                  amount: -(i.amount * 1000).round(),
                  categoryId: i.suggestedCategoryId,
                  memo: i.name.length > 100 ? i.name.substring(0, 100) : i.name,
                ))
            .toList();
      } else {
        subtransactions = null;
      }

      final tx = YnabTransactionRequest(
        accountId: _selectedAccountId!,
        date: receipt.date,
        amount: receipt.amountInMilliunits,
        cleared: 'uncleared',
        payeeId: _useCustomPayee ? null : _selectedPayeeId,
        payeeName: _useCustomPayee ? _payeeNameCtrl.text.trim() : null,
        // Single category only when not using splits
        categoryId: subtransactions == null ? _selectedCategoryId : null,
        memo: subtransactions != null
            ? '[Receipt scan — split]'
            : 'Receipt scan',
        approved: false,
        subtransactions: subtransactions,
      );

      await ref.read(ynabRepositoryProvider).createTransaction(budgetId, tx);

      if (mounted) {
        ref.read(currentReceiptProvider.notifier).state = null;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(subtransactions != null
                ? 'Split transaction created in YNAB!'
                : 'Transaction created in YNAB!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AppException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = ref.watch(currentReceiptProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final budgetId = settings?.defaultBudgetId;

    if (receipt == null) {
      return const Scaffold(body: Center(child: Text('No receipt data.')));
    }

    final hasSplits = receipt.items
        .where((i) => i.suggestedCategoryId != null && i.amount > 0)
        .length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Map to YNAB')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary card ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receipt Summary',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _SummaryRow('Merchant', receipt.merchant),
                    _SummaryRow('Date', receipt.date),
                    _SummaryRow(
                        'Total', '\$${receipt.total.toStringAsFixed(2)}'),
                    if (receipt.paymentMethod != null)
                      _SummaryRow('Card', receipt.paymentMethod!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Items with categories (split preview) ─────────────────────
            if (receipt.items.isNotEmpty) ...[
              Text('Items',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...receipt.items.map((item) => _ItemRow(item: item)),
              if (hasSplits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.call_split,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Will create a split transaction',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // ── Account ───────────────────────────────────────────────────
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (budgetId != null)
              _AccountDropdown(
                budgetId: budgetId,
                selectedId: _selectedAccountId,
                paymentMethod: receipt.paymentMethod,
                onChanged: (id) => setState(() => _selectedAccountId = id),
                onAutoDetected: (id) {
                  if (_selectedAccountId == null || _selectedAccountId == id) {
                    setState(() => _selectedAccountId = id);
                  }
                },
                detectAccountId: _detectAccountId,
              )
            else
              const Text(
                'No default budget selected. Go to Settings.',
                style: TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 20),

            // ── Payee ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payee',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () =>
                      setState(() => _useCustomPayee = !_useCustomPayee),
                  child: Text(_useCustomPayee ? 'Pick existing' : 'Enter new'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_useCustomPayee)
              TextField(
                controller: _payeeNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payee name',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              )
            else if (budgetId != null)
              _PayeeDropdown(
                budgetId: budgetId,
                selectedId: _selectedPayeeId,
                suggestedName: receipt.merchant,
                onChanged: (id) => setState(() => _selectedPayeeId = id),
              ),

            const SizedBox(height: 20),

            // ── Category (only shown when NOT using splits) ────────────────
            if (!hasSplits) ...[
              Text('Category',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (budgetId != null)
                _CategoryDropdown(
                  budgetId: budgetId,
                  selectedId: _selectedCategoryId,
                  suggestedName: receipt.suggestedCategory,
                  onChanged: (id) =>
                      setState(() => _selectedCategoryId = id),
                ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(hasSplits
                  ? 'Create Split Transaction'
                  : 'Create YNAB Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item row ────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final ReceiptItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(item.name,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('\$${item.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall),
          if (item.suggestedCategoryName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.suggestedCategoryName!.split(':').last.trim(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Dropdown widgets ─────────────────────────────────────────────────────────

class _AccountDropdown extends ConsumerWidget {
  const _AccountDropdown({
    required this.budgetId,
    required this.selectedId,
    required this.onChanged,
    required this.onAutoDetected,
    required this.detectAccountId,
    this.paymentMethod,
  });
  final String budgetId;
  final String? selectedId;
  final String? paymentMethod;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onAutoDetected;
  final String? Function(String?, List<YnabAccount>) detectAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ynabAccountsProvider(budgetId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (accounts) {
        final list = accounts as List<YnabAccount>;

        // Auto-detect account from card digits if none selected yet
        String? effectiveId = selectedId;
        if (effectiveId == null && paymentMethod != null) {
          final detected = detectAccountId(paymentMethod, list);
          if (detected != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onAutoDetected(detected);
            });
            effectiveId = detected;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effectiveId != null &&
                effectiveId != selectedId &&
                paymentMethod != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-detected from $paymentMethod',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Account'),
              value:
                  list.any((a) => a.id == effectiveId) ? effectiveId : null,
              items: list
                  .map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }
}

class _PayeeDropdown extends ConsumerWidget {
  const _PayeeDropdown({
    required this.budgetId,
    required this.selectedId,
    required this.suggestedName,
    required this.onChanged,
  });
  final String budgetId;
  final String? selectedId;
  final String suggestedName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ynabPayeesProvider(budgetId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (payees) {
        final list = payees as List<YnabPayee>;
        String? autoSelected = selectedId;
        if (autoSelected == null) {
          final match = list.where((p) =>
              p.name.toLowerCase() == suggestedName.toLowerCase());
          if (match.isNotEmpty) autoSelected = match.first.id;
        }
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Payee'),
          value: list.any((p) => p.id == autoSelected) ? autoSelected : null,
          items: list
              .map((p) =>
                  DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

class _CategoryDropdown extends ConsumerWidget {
  const _CategoryDropdown({
    required this.budgetId,
    required this.selectedId,
    required this.suggestedName,
    required this.onChanged,
  });
  final String budgetId;
  final String? selectedId;
  final String? suggestedName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ynabCategoriesProvider(budgetId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (categories) {
        final list = categories as List<YnabCategory>;
        String? autoSelected = selectedId;
        if (autoSelected == null && suggestedName != null) {
          final match = list.where((c) =>
              c.name.toLowerCase().contains(suggestedName!.toLowerCase()) ||
              suggestedName!
                  .toLowerCase()
                  .contains(c.name.toLowerCase()));
          if (match.isNotEmpty) autoSelected = match.first.id;
        }
        return DropdownButtonFormField<String>(
          decoration:
              const InputDecoration(labelText: 'Category (optional)'),
          value:
              list.any((c) => c.id == autoSelected) ? autoSelected : null,
          items: list
              .map((c) => DropdownMenuItem(
                  value: c.id, child: Text(c.displayName)))
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}
