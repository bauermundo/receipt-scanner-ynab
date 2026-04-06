// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ynab_payee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

YnabPayee _$YnabPayeeFromJson(Map<String, dynamic> json) => YnabPayee(
      id: json['id'] as String,
      name: json['name'] as String,
      deleted: json['deleted'] as bool,
    );

Map<String, dynamic> _$YnabPayeeToJson(YnabPayee instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'deleted': instance.deleted,
    };
