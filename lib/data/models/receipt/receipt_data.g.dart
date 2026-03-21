// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceiptData _$ReceiptDataFromJson(Map<String, dynamic> json) => ReceiptData(
      merchant: json['merchant'] as String,
      date: json['date'] as String,
      total: (json['total'] as num).toDouble(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      suggestedCategory: json['suggested_category'] as String?,
    );

Map<String, dynamic> _$ReceiptDataToJson(ReceiptData instance) =>
    <String, dynamic>{
      'merchant': instance.merchant,
      'date': instance.date,
      'total': instance.total,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'suggested_category': instance.suggestedCategory,
    };
