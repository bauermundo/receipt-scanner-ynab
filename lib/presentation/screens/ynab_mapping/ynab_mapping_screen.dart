import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/receipt/receipt_data.dart';
import '../../../data/models/receipt/receipt_item.dart';
import '../../../data/models/ynab/ynab_account.dart';
import '../../../data/models/ynab/ynab_category.dart';
import '../../../data/models/ynab/ynab_transaction_request.dart';

class YnabMappingScreen extends ConsumerStatefulWidget {
  const YnabMappingScreen({super.key});

  @override
  ConsumerState<YnabMappingScreen> createState() => _YnabMappingScreenState();
}

class _YnabMappingScreenState extends ConsumerState<YnabMappingScreen> {
  String? _selectedAccountId;
  String? _autoDetectedAccountId;
  bool _submitting = false;
  String? _error;

  // Per-item category overrides — keyed by item index
  final Map<int, String?> _categoryOverrides = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    _selectedAccountId = settings?.defaultAccountId;
  }

  /// Returns last 4 digits from a paymentMethod string, or null.
  String? _extractDigits(String? paymentMethod) {
    if (paymentMethod == null) return null;
    return RegExp(r'\d{4}').allMatches(paymentMethod).lastOrNull?.group(0);
  }

  /// Auto-detect account using name AND note for card digit matching.
  String? _detectAccount(String? paymentMethod, List<YnabAccount> accounts) {
    final digits = _extractDigits(paymentMethod);
    if (digits == null) return null;
    final matches = accounts.where((a) => a.matchesCardDigits(digits)).toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  String? _categoryIdForItem(int index, ReceiptItem item) =>
      _categoryOverrides.containsKey(index)
          ? _categoryOverrides[index]
          : item.suggestedCategoryId;

  Future<void> _showCategoryPicker(
      BuildContext context, int index, ReceiptItem item, String budgetId) async {
    final categories = await ref.read(ynabCategoriesProvider(budgetId).future);
    if (!context.mounted) return;

    final current = _categoryIdForItem(index, item);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                item.name,
                style: Theme.of(ctx).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('No category'),
                    selected: current == null,
                    onTap: () {
                      setState(() => _categoryOverrides[index] = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  ...(categories as List<YnabCategory>).map((cat) => ListTile(
                        title: Text(cat.name),
                        subtitle: Text(cat.categoryGroupName),
                        selected: cat.id == current,
                        selectedTileColor:
                            Theme.of(ctx).colorScheme.primaryContainer,
                        onTap: () {
                          setState(
                              () => _categoryOverrides[index] = cat.id);
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(ReceiptData receipt, String budgetId) async {
    if (_selectedAccountId == null) {
      setState(() => _error = 'Please select an account.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Build effective items (with overrides applied)
      final effectiveItems = receipt.items.asMap().entries
          .where((e) => e.value.amount > 0)
          .map((e) => (
                item: e.value,
                categoryId: _categoryIdForItem(e.key, e.value),
              ))
          .toList();

      // Use splits when 2+ items have distinct categories
      final categorizedItems =
          effectiveItems.where((e) => e.categoryId != null).toList();
      final distinctCategories =
          categorizedItems.map((e) => e.categoryId).toSet();

      final List<YnabSubtransaction>? subtransactions;
      if (categorizedItems.length > 1 && distinctCategories.length > 1) {
        // Group by category and sum amounts
        final grouped = <String, double>{};
        for (final e in categorizedItems) {
          grouped[e.categoryId!] =
              (grouped[e.categoryId!] ?? 0) + e.item.amount;
        }
        // Uncategorized items lumped into last subtransaction without category
        final uncategorized = effectiveItems
            .where((e) => e.categoryId == null)
            .fold(0.0, (sum, e) => sum + e.item.amount);

        subtransactions = [
          ...grouped.entries.map((entry) => YnabSubtransaction(
                amount: -(entry.value * 1000).round(),
                categoryId: entry.key,
              )),
          if (uncategorized > 0)
            YnabSubtransaction(amount: -(uncategorized * 1000).round()),
        ];
      } else {
        subtransactions = null;
      }

      // Single category: use the one from the dominant item (or first override)
      String? singleCategoryId;
      if (subtransactions == null && categorizedItems.isNotEmpty) {
        singleCategoryId = categorizedItems.first.categoryId;
      }

      final tx = YnabTransactionRequest(
        accountId: _selectedAccountId!,
        date: receipt.date,
        amount: receipt.amountInMilliunits,
        cleared: 'uncleared',
        payeeName: receipt.merchant,
        categoryId: subtransactions == null ? singleCategoryId : null,
        memo: subtransactions != null ? '[Receipt scan — split]' : 'Receipt scan',
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
    if (budgetId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Transaction')),
        body: const Center(
            child: Text('No default budget set. Go to Settings.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Receipt header ────────────────────────────────────────────
            _ReceiptHeader(receipt: receipt),
            const SizedBox(height: 20),

            // ── Account ───────────────────────────────────────────────────
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _AccountSection(
              budgetId: budgetId,
              selectedId: _selectedAccountId,
              paymentMethod: receipt.paymentMethod,
              detectAccount: _detectAccount,
              onChanged: (id) => setState(() => _selectedAccountId = id),
              onAutoDetected: (id) {
                if (_autoDetectedAccountId != id) {
                  _autoDetectedAccountId = id;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedAccountId == null ||
                        _selectedAccountId ==
                            settings?.defaultAccountId) {
                      setState(() => _selectedAccountId = id);
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // ── Items ─────────────────────────────────────────────────────
            if (receipt.items.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Items',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'Tap category to change',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: receipt.items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final catId = _categoryIdForItem(i, item);
                    final catName = catId != null
                        ? item.suggestedCategoryName
                            ?.split(':')
                            .last
                            .trim()
                        : null;

                    return _ItemTile(
                      item: item,
                      categoryName: catName,
                      onTap: () =>
                          _showCategoryPicker(context, i, item, budgetId),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(receipt, budgetId),
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Submit to YNAB'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Receipt header card ──────────────────────────────────────────────────────

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({required this.receipt});
  final ReceiptData receipt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    receipt.merchant,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '\$${receipt.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14,
                    color: Colors.grey),
                const SizedBox(width: 6),
                Text(receipt.date,
                    style: Theme.of(context).textTheme.bodySmall),
                if (receipt.paymentMethod != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.credit_card, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(receipt.paymentMethod!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Account section ──────────────────────────────────────────────────────────

class _AccountSection extends ConsumerWidget {
  const _AccountSection({
    required this.budgetId,
    required this.selectedId,
    required this.onChanged,
    required this.onAutoDetected,
    required this.detectAccount,
    this.paymentMethod,
  });

  final String budgetId;
  final String? selectedId;
  final String? paymentMethod;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onAutoDetected;
  final String? Function(String?, List<YnabAccount>) detectAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ynabAccountsProvider(budgetId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (rawAccounts) {
        final accounts = rawAccounts as List<YnabAccount>;
        String? effectiveId = selectedId;

        if (effectiveId == null && paymentMethod != null) {
          final detected = detectAccount(paymentMethod, accounts);
          if (detected != null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onAutoDetected(detected));
            effectiveId = detected;
          }
        }

        final detectedAccount = effectiveId != null
            ? accounts.where((a) => a.id == effectiveId).firstOrNull
            : null;
        final isAutoDetected = paymentMethod != null &&
            detectedAccount != null &&
            detectedAccount.matchesCardDigits(
                RegExp(r'\d{4}')
                        .allMatches(paymentMethod!)
                        .lastOrNull
                        ?.group(0) ??
                    '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAutoDetected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Auto-matched from $paymentMethod',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Account',
                border: OutlineInputBorder(),
                filled: true,
              ),
              value: accounts.any((a) => a.id == effectiveId)
                  ? effectiveId
                  : null,
              items: accounts
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

// ── Item tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onTap,
    this.categoryName,
  });

  final ReceiptItem item;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: categoryName != null
          ? GestureDetector(
              onTap: onTap,
              child: Chip(
                label: Text(
                  categoryName!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
              ),
            )
          : TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('+ Add category'),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${item.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.outline),
        ],
      ),
      onTap: onTap,
    );
  }
}
