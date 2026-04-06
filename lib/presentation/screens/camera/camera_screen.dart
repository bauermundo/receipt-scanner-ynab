import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/settings_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../router.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    final settings = ref.read(settingsNotifierProvider).valueOrNull;

    if (settings?.hasAnthropicKey != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your Anthropic API key in Settings first.'),
        ),
      );
      return;
    }

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not access camera/gallery: $e');
      return;
    }

    if (picked == null || !mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(receiptRepositoryProvider);
      // Fetch YNAB categories so Claude can assign them per item
      final settings = ref.read(settingsNotifierProvider).valueOrNull;
      final budgetId = settings?.defaultBudgetId;
      final categories = budgetId != null
          ? await ref.read(ynabCategoriesProvider(budgetId).future).catchError((_) => <dynamic>[])
          : null;
      final receipt = await repo.parseReceiptFromImage(
        File(picked.path),
        ynabCategories: categories?.cast(),
      );
      ref.read(currentReceiptProvider.notifier).state = receipt;
      if (mounted) {
        Navigator.of(context).pushNamed(AppRouter.review);
      }
    } on AppException catch (e) {
      setState(() => _errorMessage = e.userMessage);
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.settings),
          ),
        ],
      ),
      body: _loading
          ? const _LoadingView()
          : _HomeContent(
              errorMessage: _errorMessage,
              onPickImage: _pickImage,
            ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Analysing receipt with Claude AI…'),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.errorMessage,
    required this.onPickImage,
  });

  final String? errorMessage;
  final void Function(ImageSource) onPickImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Scan a Receipt',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo or choose from your gallery.\nClaude AI will extract the details.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () => onPickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => onPickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose from Gallery'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
