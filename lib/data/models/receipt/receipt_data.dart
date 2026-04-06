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
    this.paymentMethod,
    this.memo,
  });

  final String merchant;

  /// ISO 8601 date string, e.g. "2026-03-21"
  final String date;

  final double total;
  final List<ReceiptItem> items;

  @JsonKey(name: 'suggested_category')
  final String? suggestedCategory;

  /// Card type + last 4 digits visible on receipt, e.g. "Visa 2902"
  @JsonKey(name: 'payment_method')
  final String? paymentMethod;

  /// Short memo for YNAB — item list for small orders, AI summary for large ones.
  final String? memo;

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
    String? paymentMethod,
    String? memo,
  }) {
    return ReceiptData(
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      items: items ?? this.items,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      memo: memo ?? this.memo,
    );
  }
}
