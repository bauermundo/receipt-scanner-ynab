import 'package:json_annotation/json_annotation.dart';

part 'receipt_item.g.dart';

@JsonSerializable()
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.amount,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
  });

  final String name;
  final double amount;

  @JsonKey(name: 'suggested_category_id')
  final String? suggestedCategoryId;

  @JsonKey(name: 'suggested_category_name')
  final String? suggestedCategoryName;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);

  Map<String, dynamic> toJson() => _$ReceiptItemToJson(this);

  ReceiptItem copyWith({
    String? name,
    double? amount,
    String? suggestedCategoryId,
    String? suggestedCategoryName,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedCategoryName:
          suggestedCategoryName ?? this.suggestedCategoryName,
    );
  }
}
