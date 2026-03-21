import 'package:json_annotation/json_annotation.dart';
import 'receipt_item.dart';

part 'receipt_data.g.dart';

@JsonSerializable(explicitToJson: true)
class ReceiptData {
  const ReceiptData({
    required this.merchant,
    required this.date,
    required this.total,
    this.items = const [],
    this.suggestedCategory,
  });

  final String merchant;

  /// ISO 8601 date string, e.g. "2026-03-21"
  final String date;

  final double total;
  final List<ReceiptItem> items;

  @JsonKey(name: 'suggested_category')
  final String? suggestedCategory;

  /// Amount in YNAB milliunits (negative = outflow).
  int get amountInMilliunits => -(total * 1000).round();

  factory ReceiptData.fromJson(Map<String, dynamic> json) =>
      _$ReceiptDataFromJson(json);

  Map<String, dynamic> toJson() => _$ReceiptDataToJson(this);

  ReceiptData copyWith({
    String? merchant,
    String? date,
    double? total,
    List<ReceiptItem>? items,
    String? suggestedCategory,
  }) {
    return ReceiptData(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      items: items ?? this.items,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
    );
  }
}
