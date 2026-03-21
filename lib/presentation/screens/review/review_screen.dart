import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/receipt/receipt_data.dart';
import '../../../data/models/receipt/receipt_item.dart';
import '../../../router.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late TextEditingController _merchantCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _totalCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final receipt = ref.read(currentReceiptProvider)!;
    _merchantCtrl = TextEditingController(text: receipt.merchant);
    _dateCtrl = TextEditingController(text: receipt.date);
    _totalCtrl = TextEditingController(text: receipt.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _dateCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!_formKey.currentState!.validate()) return;

    final existing = ref.read(currentReceiptProvider)!;
    final updated = existing.copyWith(
      merchant: _merchantCtrl.text.trim(),
      date: _normaliseDate(_dateCtrl.text.trim()),
      total: double.parse(_totalCtrl.text.trim()),
    );
    ref.read(currentReceiptProvider.notifier).state = updated;
    Navigator.of(context).pushNamed(AppRouter.ynabMapping);
  }

  /// Try to normalise common date formats to ISO 8601.
  String _normaliseDate(String input) {
    final formats = [
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('MMMM d, yyyy'),
      DateFormat('MMM d, yyyy'),
      DateFormat('d MMMM yyyy'),
    ];
    for (final fmt in formats) {
      try {
        final parsed = fmt.parseStrict(input);
        return DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {}
    }
    return input; // return as-is if no format matched
  }

  @override
  Widget build(BuildContext context) {
    final receipt = ref.watch(currentReceiptProvider);
    if (receipt == null) {
      return const Scaffold(
        body: Center(child: Text('No receipt data available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          TextButton(
            onPressed: _proceed,
            child: const Text('Continue'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Extracted Data',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Review and correct the information below before sending to YNAB.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _merchantCtrl,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Payee',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_dateCtrl.text) ??
                        DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),

              if (receipt.suggestedCategory != null) ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Suggested Category',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  child: Text(receipt.suggestedCategory!),
                ),
              ],

              if (receipt.items.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ItemsList(items: receipt.items),
              ],

              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _proceed,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Map to YNAB'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.items});
  final List<ReceiptItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                dense: true,
                title: Text(item.name),
                trailing: Text(
                  '\$${item.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
