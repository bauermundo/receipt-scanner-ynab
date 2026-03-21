import 'package:json_annotation/json_annotation.dart';

part 'receipt_item.g.dart';

@JsonSerializable()
class ReceiptItem {
  const ReceiptItem({required this.name, required this.amount});

  final String name;
  final double amount;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);

  Map<String, dynamic> toJson() => _$ReceiptItemToJson(this);

  ReceiptItem copyWith({String? name, double? amount}) {
    return ReceiptItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }
}
