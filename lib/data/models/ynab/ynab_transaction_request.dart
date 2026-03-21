import 'package:json_annotation/json_annotation.dart';

part 'ynab_transaction_request.g.dart';

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

  factory YnabTransactionRequest.fromJson(Map<String, dynamic> json) =>
      _$YnabTransactionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$YnabTransactionRequestToJson(this);
}
