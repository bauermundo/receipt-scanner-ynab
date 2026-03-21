import 'package:json_annotation/json_annotation.dart';

part 'ynab_payee.g.dart';

@JsonSerializable()
class YnabPayee {
  const YnabPayee({
    required this.id,
    required this.name,
    required this.deleted,
  });

  final String id;
  final String name;
  final bool deleted;

  factory YnabPayee.fromJson(Map<String, dynamic> json) =>
      _$YnabPayeeFromJson(json);

  Map<String, dynamic> toJson() => _$YnabPayeeToJson(this);

  @override
  String toString() => name;
}
