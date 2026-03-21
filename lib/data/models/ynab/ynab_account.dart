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
  });

  final String id;
  final String name;
  final String type;

  @JsonKey(name: 'on_budget')
  final bool onBudget;

  final bool closed;

  factory YnabAccount.fromJson(Map<String, dynamic> json) =>
      _$YnabAccountFromJson(json);

  Map<String, dynamic> toJson() => _$YnabAccountToJson(this);

  @override
  String toString() => name;
}
