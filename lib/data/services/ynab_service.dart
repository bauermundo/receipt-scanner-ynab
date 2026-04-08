import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/ynab/ynab_account.dart';
import '../models/ynab/ynab_budget.dart';
import '../models/ynab/ynab_category.dart';
import '../models/ynab/ynab_transaction_request.dart';

class YnabService {
  YnabService(this._client);

  final http.Client _client;

  // ── Budgets ────────────────────────────────────────────────────────────────

  Future<List<YnabBudget>> getBudgets(String token) async {
    final data = await _get(token, ApiConstants.ynabBudgetsEndpoint);
    final budgetList = data['budgets'] as List;
    return budgetList
        .map((b) => YnabBudget.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  // ── Accounts ───────────────────────────────────────────────────────────────

  Future<List<YnabAccount>> getAccounts(
      String token, String budgetId) async {
    final data = await _get(
        token, '${ApiConstants.ynabBudgetsEndpoint}/$budgetId/accounts');
    final list = data['accounts'] as List;
    return list
        .map((a) => YnabAccount.fromJson(a as Map<String, dynamic>))
        .where((a) => !a.closed)
        .toList();
  }

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<YnabCategory>> getCategories(
      String token, String budgetId) async {
    final data = await _get(
        token, '${ApiConstants.ynabBudgetsEndpoint}/$budgetId/categories');
    final groups = data['category_groups'] as List;
    final categories = <YnabCategory>[];
    for (final group in groups) {
      final g = YnabCategoryGroup.fromJson(group as Map<String, dynamic>);
      if (g.hidden || g.deleted) continue;
      for (final raw in g.categories) {
        if (raw.hidden || raw.deleted) continue;
        categories.add(YnabCategory(
          id: raw.id,
          name: raw.name,
          categoryGroupName: g.name,
          hidden: raw.hidden,
          deleted: raw.deleted,
        ));
      }
    }
    return categories;
  }

  // ── Create transaction ─────────────────────────────────────────────────────

  Future<void> createTransaction(
      String token, String budgetId, YnabTransactionRequest tx) async {
    final body = jsonEncode({'transaction': tx.toJson()});
    final response = await _client.post(
      Uri.parse(
          '${ApiConstants.ynabBaseUrl}${ApiConstants.ynabBudgetsEndpoint}/$budgetId/transactions'),
      headers: _headers(token),
      body: body,
    );

    if (response.statusCode != 201) {
      final detail = response.body;
      if (response.statusCode == 401) {
        throw const YnabException(
            'Invalid YNAB token. Please check Settings.', 'HTTP 401');
      }
      throw YnabException(
          'Failed to create transaction (${response.statusCode}).',
          'HTTP ${response.statusCode}: $detail');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String token, String path) async {
    final response = await _client.get(
      Uri.parse('${ApiConstants.ynabBaseUrl}$path'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw const YnabException(
            'Invalid YNAB token. Please check Settings.', 'HTTP 401');
      }
      throw YnabException(
          'YNAB request failed (${response.statusCode}).',
          'GET $path → HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}
