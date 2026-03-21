// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ynab_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

YnabCategory _$YnabCategoryFromJson(Map<String, dynamic> json) => YnabCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryGroupName: json['categoryGroupName'] as String,
      hidden: json['hidden'] as bool,
      deleted: json['deleted'] as bool,
    );

Map<String, dynamic> _$YnabCategoryToJson(YnabCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'categoryGroupName': instance.categoryGroupName,
      'hidden': instance.hidden,
      'deleted': instance.deleted,
    };

YnabCategoryGroup _$YnabCategoryGroupFromJson(Map<String, dynamic> json) =>
    YnabCategoryGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      hidden: json['hidden'] as bool,
      deleted: json['deleted'] as bool,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => YnabCategoryRaw.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$YnabCategoryGroupToJson(YnabCategoryGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hidden': instance.hidden,
      'deleted': instance.deleted,
      'categories': instance.categories.map((e) => e.toJson()).toList(),
    };

YnabCategoryRaw _$YnabCategoryRawFromJson(Map<String, dynamic> json) =>
    YnabCategoryRaw(
      id: json['id'] as String,
      name: json['name'] as String,
      hidden: json['hidden'] as bool,
      deleted: json['deleted'] as bool,
    );

Map<String, dynamic> _$YnabCategoryRawToJson(YnabCategoryRaw instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hidden': instance.hidden,
      'deleted': instance.deleted,
    };
