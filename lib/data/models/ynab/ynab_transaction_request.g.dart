// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ynab_transaction_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

YnabTransactionRequest _$YnabTransactionRequestFromJson(
        Map<String, dynamic> json) =>
    YnabTransactionRequest(
      accountId: json['account_id'] as String,
      date: json['date'] as String,
      amount: (json['amount'] as num).toInt(),
      cleared: json['cleared'] as String,
      payeeId: json['payee_id'] as String?,
      payeeName: json['payee_name'] as String?,
      categoryId: json['category_id'] as String?,
      memo: json['memo'] as String?,
      approved: json['approved'] as bool? ?? true,
    );

Map<String, dynamic> _$YnabTransactionRequestToJson(
    YnabTransactionRequest instance) {
  final val = <String, dynamic>{
    'account_id': instance.accountId,
    'date': instance.date,
    'amount': instance.amount,
    'cleared': instance.cleared,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('payee_id', instance.payeeId);
  writeNotNull('payee_name', instance.payeeName);
  writeNotNull('category_id', instance.categoryId);
  writeNotNull('memo', instance.memo);
  val['approved'] = instance.approved;
  return val;
}
