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
        YnabTransactionRequest instance) =>
    <String, dynamic>{
      'account_id': instance.accountId,
      'date': instance.date,
      'amount': instance.amount,
      'cleared': instance.cleared,
      if (instance.payeeId case final value?) 'payee_id': value,
      if (instance.payeeName case final value?) 'payee_name': value,
      if (instance.categoryId case final value?) 'category_id': value,
      if (instance.memo case final value?) 'memo': value,
      'approved': instance.approved,
      if (instance.subtransactions case final value?)
        'subtransactions':
            YnabTransactionRequest._subtransactionsToJson(value),
    };
