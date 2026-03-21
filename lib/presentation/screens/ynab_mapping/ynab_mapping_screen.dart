import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../core/errors/app_exception.dart';
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
    _payeeNameCtrl =
        TextEditingController(text: receipt?.merchant ?? '');

    // Pre-fill account from settings default
    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    _selectedAccountId = settings?.defaultAccountId;
  }

  @override
  void dispose() {
    _payeeNameCtrl.dispose();
    super.dispose();
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
      final tx = YnabTransactionRequest(
        accountId: _selectedAccountId!,
        date: receipt.date,
        amount: receipt.amountInMilliunits,
        cleared: 'uncleared',
        payeeId: _useCustomPayee ? null : _selectedPayeeId,
        payeeName: _useCustomPayee ? _payeeNameCtrl.text.trim() : null,
        categoryId: _selectedCategoryId,
        memo: 'Receipt scan',
        approved: false,
      );

      await ref.read(ynabRepositoryProvider).createTransaction(budgetId, tx);

      if (mounted) {
        // Clear the receipt and return to home
        ref.read(currentReceiptProvider.notifier).state = null;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction created in YNAB!'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Map to YNAB')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary card ────────────────────────────────────────────────
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Account ─────────────────────────────────────────────────────
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (budgetId != null)
              _AccountDropdown(
                budgetId: budgetId,
                selectedId: _selectedAccountId,
                onChanged: (id) =>
                    setState(() => _selectedAccountId = id),
              )
            else
              const Text(
                'No default budget selected. Go to Settings.',
                style: TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 20),

            // ── Payee ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payee',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () =>
                      setState(() => _useCustomPayee = !_useCustomPayee),
                  child:
                      Text(_useCustomPayee ? 'Pick existing' : 'Enter new'),
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
                onChanged: (id) =>
                    setState(() => _selectedPayeeId = id),
              ),

            const SizedBox(height: 20),

            // ── Category ─────────────────────────────────────────────────────
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
              label: const Text('Create YNAB Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

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
          Text(label,
              style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Dropdown widgets ────────────────────────────────────────────────────────────

class _AccountDropdown extends ConsumerWidget {
  const _AccountDropdown({
    required this.budgetId,
    required this.selectedId,
    required this.onChanged,
  });
  final String budgetId;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ynabAccountsProvider(budgetId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (accounts) {
        final list = accounts as List<YnabAccount>;
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Account'),
          value: list.any((a) => a.id == selectedId) ? selectedId : null,
          items: list
              .map((a) =>
                  DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: onChanged,
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
        // Try to auto-select matching payee by name (case-insensitive)
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
        // Auto-select category if suggestion matches
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
          decoration: const InputDecoration(labelText: 'Category (optional)'),
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
