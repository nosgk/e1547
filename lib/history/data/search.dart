import 'package:e1547/history/history.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

extension HistorySearchFilterDisplaying on HistoryCategory {
  String get title {
    switch (this) {
      case HistoryCategory.items:
        return 'Items'.tr;
      case HistoryCategory.searches:
        return 'Searches'.tr;
    }
  }

  Widget? get icon {
    switch (this) {
      case HistoryCategory.items:
        return const Icon(Icons.article);
      case HistoryCategory.searches:
        return const Icon(Icons.search);
    }
  }
}

extension HistoryTypeFilterDisplaying on HistoryType {
  String get title => switch (this) {
    HistoryType.posts => 'Posts'.tr,
    HistoryType.pools => 'Pools'.tr,
    HistoryType.topics => 'Topics'.tr,
    HistoryType.wikis => 'Wikis'.tr,
    HistoryType.users => 'Users'.tr,
  };

  Widget? get icon => switch (this) {
    HistoryType.posts => const Icon(Icons.image),
    HistoryType.pools => const Icon(Icons.collections),
    HistoryType.topics => const Icon(Icons.forum),
    HistoryType.users => const Icon(Icons.person),
    HistoryType.wikis => const Icon(Icons.info_outlined),
  };
}
