// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ynab_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

YnabAccount _$YnabAccountFromJson(Map<String, dynamic> json) => YnabAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      onBudget: json['on_budget'] as bool,
      closed: json['closed'] as bool,
    );

Map<String, dynamic> _$YnabAccountToJson(YnabAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'on_budget': instance.onBudget,
      'closed': instance.closed,
    };
