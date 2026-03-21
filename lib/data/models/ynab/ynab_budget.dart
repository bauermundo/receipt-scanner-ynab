import 'package:json_annotation/json_annotation.dart';

part 'ynab_budget.g.dart';

@JsonSerializable()
class YnabBudget {
  const YnabBudget({required this.id, required this.name});

  final String id;
  final String name;

  factory YnabBudget.fromJson(Map<String, dynamic> json) =>
      _$YnabBudgetFromJson(json);

  Map<String, dynamic> toJson() => _$YnabBudgetToJson(this);

  @override
  String toString() => name;
}
