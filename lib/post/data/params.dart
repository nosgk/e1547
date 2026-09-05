import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'params.freezed.dart';

enum PostOrder {
  newest('new'),
  score('score'),
  favcount('favcount'),
  rank('rank'),
  random('random');

  const PostOrder(this.value);

  final String value;
}

@freezed
abstract class PostParams with _$PostParams {
  const factory PostParams({String? tags}) = _PostParams;

  const PostParams._();

  QueryMap toQuery() => <String, Object?>{'tags': tags}.toQuery();

  /// The id of the pool this search lists, when its tags are a pool tag with
  /// at most an order.
  int? get poolId {
    final map = TagMap(tags);
    final id = int.tryParse(map['pool'] ?? '');
    if (id == null) return null;
    if (map.length == 1) return id;
    if (map.length == 2 && map['order'] != null) return id;
    return null;
  }

  bool get poolOldestFirst {
    final order = TagMap(tags)['order'];
    return order == null || order == 'pool';
  }

  static final tagsFilter = NestedFilterTag(
    tag: 'tags',
    decode: TagMap.new,
    encode: (value) => TagMap.from(value).toString(),
    filters: [
      NumberRangeFilterTag(
        tag: 'score',
        name: 'Score'.tr,
        min: 0,
        max: 100,
        division: 10,
        initial: const NumberRange(
          20,
          comparison: NumberComparison.greaterThanOrEqual,
        ),
        icon: const Icon(Icons.arrow_upward),
      ),
      NumberRangeFilterTag(
        tag: 'favcount',
        name: 'Favorite count'.tr,
        min: 0,
        max: 100,
        division: 10,
        initial: const NumberRange(
          20,
          comparison: NumberComparison.greaterThanOrEqual,
        ),
        icon: const Icon(Icons.favorite),
      ),
      EnumFilterTag<PostOrder>(
        tag: 'order',
        name: 'Sort by'.tr,
        values: PostOrder.values,
        valueMapper: (value) => value.value,
        nameMapper: (value) => switch (value) {
          PostOrder.newest => 'New'.tr,
          PostOrder.score => 'Score'.tr,
          PostOrder.favcount => 'Favorites'.tr,
          PostOrder.rank => 'Rank'.tr,
          PostOrder.random => 'Random'.tr,
        },
        undefinedOption: EnumFilterNullTagValue(name: 'Default'.tr),
        icon: const Icon(Icons.sort),
      ),
      EnumFilterTag(
        tag: 'rating',
        name: 'Rating'.tr,
        values: Rating.values,
        valueMapper: (value) => value.name,
        nameMapper: (value) => switch (value) {
          Rating.s => 'Safe'.tr,
          Rating.q => 'Questionable'.tr,
          Rating.e => 'Explicit'.tr,
        },
        undefinedOption: EnumFilterNullTagValue(name: 'All'.tr),
        icon: const Icon(Icons.question_mark),
      ),
      BooleanFilterTag(
        tag: 'inpool',
        name: 'Pool'.tr,
        description: 'Has pool'.tr,
        tristate: true,
      ),
      BooleanFilterTag(
        tag: 'ischild',
        name: 'Child'.tr,
        description: 'Is child post'.tr,
        tristate: true,
      ),
      BooleanFilterTag(
        tag: 'isparent',
        name: 'Parent'.tr,
        description: 'Is parent post'.tr,
        tristate: true,
      ),
      ChoiceFilterTag(
        tag: 'date',
        name: 'Upload date'.tr,
        options: [
          ChoiceFilterTagValue(value: null, name: 'All'.tr),
          ChoiceFilterTagValue(value: 'day', name: 'Last day'.tr),
          ChoiceFilterTagValue(value: 'week', name: 'Last week'.tr),
          ChoiceFilterTagValue(value: 'month', name: 'Last Month'.tr),
          ChoiceFilterTagValue(value: 'year', name: 'Last Year'.tr),
        ],
        icon: const Icon(Icons.date_range),
      ),
      ChoiceFilterTag(
        tag: 'status',
        name: 'Status'.tr,
        options: [
          ChoiceFilterTagValue(value: null, name: 'Default'.tr),
          ChoiceFilterTagValue(value: 'active', name: 'Active'.tr),
          ChoiceFilterTagValue(value: 'pending', name: 'Pending'.tr),
          ChoiceFilterTagValue(value: 'deleted', name: 'Deleted'.tr),
          ChoiceFilterTagValue(value: 'flagged', name: 'Flagged'.tr),
          ChoiceFilterTagValue(value: 'any', name: 'Any'.tr),
        ],
        icon: const Icon(Icons.help),
      ),
    ],
  );
}

enum PostDisplayType { grid, comic, timeline }

class PostDisplayController extends ValueNotifier<PostDisplayType> {
  PostDisplayController([PostDisplayType? initial])
    : super(initial ?? PostDisplayType.grid);
}

class PostParamsController extends ValueNotifier<PostParams> {
  PostParamsController({PostParams? initial, this.canSearch = true})
    : super(initial ?? const PostParams());

  /// Whether the owning page offers search affordances, meaning the tag
  /// actions and the search button. The mutating methods below are not gated.
  final bool canSearch;

  void update(PostParams Function(PostParams) updater) =>
      value = updater(value);

  TagMap get _tagMap => TagMap(value.tags);

  void _writeTags(TagMap map) =>
      update((p) => p.copyWith(tags: map.toString()));

  void addTag(String tag) => _writeTags(_tagMap..add(tag));

  void removeTag(String tag) => _writeTags(_tagMap..remove(tag));

  void subtractTag(String tag) => addTag('-$tag');

  bool hasTag(String tag) => _tagMap.containsKey(tag);
}
