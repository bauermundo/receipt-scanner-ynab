import 'package:json_annotation/json_annotation.dart';

part 'ynab_account.g.dart';

@JsonSerializable()
class YnabAccount {
  const YnabAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.onBudget,
    required this.closed,
    this.note,
  });

  final String id;
  final String name;
  final String type;

  @JsonKey(name: 'on_budget')
  final bool onBudget;

  final bool closed;

  /// Optional note set by the user in YNAB (e.g. "Target debit card 1234").
  final String? note;

  /// Returns true if this account's name or note contains [digits].
  bool matchesCardDigits(String digits) =>
      name.contains(digits) ||
      (note != null && note!.contains(digits));

  factory YnabAccount.fromJson(Map<String, dynamic> json) =>
      _$YnabAccountFromJson(json);

  Map<String, dynamic> toJson() => _$YnabAccountToJson(this);

  @override
  String toString() => name;
}
