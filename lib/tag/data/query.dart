import 'package:collection/collection.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';

extension TagQuerying on TagClient {
  List<Object> get queryKey => dio.identityQueryKey('tags');

  CachedQuery get queryCache => dio.queryCache!;

  /// Exact visible-post count of [tag] from the tags index, or null when
  /// the tag does not exist. Unlike `/posts/count.json`, this is never
  /// capped, which is why bare-tag searches prefer it; it is also the same
  /// number the tag prompt's count line shows.
  Query<int?> useCount({required String tag}) => Query(
    cache: queryCache,
    key: [...queryKey, 'count', tag],
    queryFn: () async {
      final results = await page(
        query: {'search[name_matches]': tag},
        limit: 1,
      );
      return results.where((e) => e.name == tag).firstOrNull?.count;
    },
  );
}
