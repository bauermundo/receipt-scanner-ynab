import '../models/ynab/ynab_account.dart';
import '../models/ynab/ynab_budget.dart';
import '../models/ynab/ynab_category.dart';
import '../models/ynab/ynab_payee.dart';
import '../models/ynab/ynab_transaction_request.dart';
import '../services/storage_service.dart';
import '../services/ynab_service.dart';
import '../../core/errors/app_exception.dart';

class YnabRepository {
  YnabRepository(this._ynabService, this._storageService);

  final YnabService _ynabService;
  final StorageService _storageService;

  Future<String> _requireToken() async {
    final token = await _storageService.getYnabAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw const YnabException(
          'Not connected to YNAB. Please connect in Settings.', 'Missing token');
    }
    return token;
  }

  Future<List<YnabBudget>> getBudgets() async {
    final token = await _requireToken();
    return _ynabService.getBudgets(token);
  }

  Future<List<YnabAccount>> getAccounts(String budgetId) async {
    final token = await _requireToken();
    return _ynabService.getAccounts(token, budgetId);
  }

  Future<List<YnabCategory>> getCategories(String budgetId) async {
    final token = await _requireToken();
    return _ynabService.getCategories(token, budgetId);
  }

  Future<List<YnabPayee>> getPayees(String budgetId) async {
    final token = await _requireToken();
    return _ynabService.getPayees(token, budgetId);
  }

  Future<void> createTransaction(
      String budgetId, YnabTransactionRequest tx) async {
    final token = await _requireToken();
    return _ynabService.createTransaction(token, budgetId, tx);
  }
}
