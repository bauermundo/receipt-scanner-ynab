import 'package:json_annotation/json_annotation.dart';

part 'ynab_transaction_request.g.dart';

/// A single subtransaction within a YNAB split transaction.
class YnabSubtransaction {
  const YnabSubtransaction({
    required this.amount,
    this.categoryId,
    this.memo,
    this.payeeName,
  });

  /// Amount in milliunits. Negative = outflow.
  final int amount;

  final String? categoryId;
  final String? memo;
  final String? payeeName;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        if (categoryId != null) 'category_id': categoryId,
        if (memo != null) 'memo': memo,
        if (payeeName != null) 'payee_name': payeeName,
      };
}

@JsonSerializable(includeIfNull: false)
class YnabTransactionRequest {
  YnabTransactionRequest({
    required this.accountId,
    required this.date,
    required this.amount,
    required this.cleared,
    this.payeeId,
    this.payeeName,
    this.categoryId,
    this.memo,
    this.approved = true,
    this.subtransactions,
  }) : assert(
          !(payeeId != null && payeeName != null),
          'Provide either payeeId or payeeName, not both',
        );

  @JsonKey(name: 'account_id')
  final String accountId;

  /// ISO 8601 date string, e.g. "2026-03-21"
  final String date;

  /// Amount in milliunits. Negative = outflow.
  final int amount;

  /// "cleared", "uncleared", or "reconciled"
  final String cleared;

  @JsonKey(name: 'payee_id')
  final String? payeeId;

  @JsonKey(name: 'payee_name')
  final String? payeeName;

  @JsonKey(name: 'category_id')
  final String? categoryId;

  final String? memo;
  final bool approved;

  /// When set, creates a split transaction. Each entry covers a portion of
  /// [amount]. The sum of subtransaction amounts must equal [amount].
  @JsonKey(includeIfNull: false, toJson: _subtransactionsToJson)
  final List<YnabSubtransaction>? subtransactions;

  static List<Map<String, dynamic>>? _subtransactionsToJson(
          List<YnabSubtransaction>? items) =>
      items?.map((s) => s.toJson()).toList();

  factory YnabTransactionRequest.fromJson(Map<String, dynamic> json) =>
      _$YnabTransactionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$YnabTransactionRequestToJson(this);
}
