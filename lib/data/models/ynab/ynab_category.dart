import 'package:json_annotation/json_annotation.dart';

part 'ynab_category.g.dart';

@JsonSerializable()
class YnabCategory {
  const YnabCategory({
    required this.id,
    required this.name,
    required this.categoryGroupName,
    required this.hidden,
    required this.deleted,
  });

  final String id;
  final String name;
  final String categoryGroupName;
  final bool hidden;
  final bool deleted;

  String get displayName => '$categoryGroupName / $name';

  factory YnabCategory.fromJson(Map<String, dynamic> json) =>
      _$YnabCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$YnabCategoryToJson(this);

  @override
  String toString() => displayName;
}

@JsonSerializable(explicitToJson: true)
class YnabCategoryGroup {
  const YnabCategoryGroup({
    required this.id,
    required this.name,
    required this.hidden,
    required this.deleted,
    required this.categories,
  });

  final String id;
  final String name;
  final bool hidden;
  final bool deleted;
  final List<YnabCategoryRaw> categories;

  factory YnabCategoryGroup.fromJson(Map<String, dynamic> json) =>
      _$YnabCategoryGroupFromJson(json);

  Map<String, dynamic> toJson() => _$YnabCategoryGroupToJson(this);
}

@JsonSerializable()
class YnabCategoryRaw {
  const YnabCategoryRaw({
    required this.id,
    required this.name,
    required this.hidden,
    required this.deleted,
  });

  final String id;
  final String name;
  final bool hidden;
  final bool deleted;

  factory YnabCategoryRaw.fromJson(Map<String, dynamic> json) =>
      _$YnabCategoryRawFromJson(json);

  Map<String, dynamic> toJson() => _$YnabCategoryRawToJson(this);
}
