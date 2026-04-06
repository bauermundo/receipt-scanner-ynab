// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceiptItem _$ReceiptItemFromJson(Map<String, dynamic> json) => ReceiptItem(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      suggestedCategoryId: json['suggested_category_id'] as String?,
      suggestedCategoryName: json['suggested_category_name'] as String?,
    );

Map<String, dynamic> _$ReceiptItemToJson(ReceiptItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'amount': instance.amount,
      'suggested_category_id': instance.suggestedCategoryId,
      'suggested_category_name': instance.suggestedCategoryName,
    };
