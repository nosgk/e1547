/// Codec between a post search and its canonical e621 web URL.
///
/// The web frontend exposes a search as `https://e621.net/posts?tags=…`
/// (plus `limit` and `page`); the newer `search[tags]` spelling is accepted
/// on input as well. Encoding always produces the canonical `tags=` form so
/// shared links stay readable and short.
library;

import 'package:e1547/post/post.dart';

const Set<String> postSearchHosts = {'e621.net', 'e926.net'};

/// A post search extracted from a web URL.
class PostSearchUrl {
  const PostSearchUrl({this.tags, this.limit, this.page});

  final String? tags;
  final int? limit;
  final int? page;

  @override
  String toString() => 'PostSearchUrl(tags: $tags, limit: $limit, page: $page)';
}

abstract final class PostSearchUrlCodec {
  /// Hard server limits; see docs/e621-api.md §4.
  static const int maxLimit = 320;
  static const int maxNumberedPage = 750;

  /// Link-parser entry: a query map from an e621 posts URL.
  static PostSearchUrl parseLink(Map<String, String>? query) =>
      PostSearchUrlLinking.fromQuery(query);

  /// The canonical web URL of [params]. `limit` and `page` are only emitted
  /// when they carry meaning (a bare first page is the site default).
  static String encode(PostParams params, {int? limit, int? page}) {
    final Map<String, String> query = {};
    final String tags = params.tags ?? '';
    if (tags.isNotEmpty) query['tags'] = tags;
    // The site's own default page size makes an explicit limit noise, and
    // the first page is the default; keep canonical URLs minimal.
    if (limit != null && limit != 75) {
      query['limit'] = limit.clamp(1, maxLimit).toString();
    }
    if (page != null && page > 1) query['page'] = page.toString();
    return Uri(
      scheme: 'https',
      host: 'e621.net',
      path: '/posts',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  /// Parses a post search from a web URL, returning null when [uri] is not
  /// an e621/e926 posts search. Accepts both `tags=` and the newer
  /// `search[tags]=` spellings; `limit` is clamped into the legal range and
  /// an out-of-range numbered `page` is dropped (the API errors above 750).
  static PostSearchUrl? parse(Uri uri) {
    if (!postSearchHosts.contains(uri.host)) return null;
    final String? segment = uri.pathSegments.firstOrNull;
    if (segment != 'posts') return null;

    String? read(List<String> keys) {
      for (final String key in keys) {
        final String? value = uri.queryParameters[key];
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final String? tags = read(['tags', 'search[tags]']);
    final int? limit = int.tryParse(read(['limit', 'search[limit]']) ?? '');
    final int? page = int.tryParse(read(['page']) ?? '');
    return PostSearchUrl(
      tags: tags,
      limit: limit?.clamp(1, PostSearchUrlCodec.maxLimit),
      page:
          page != null &&
              page >= 1 &&
              page <= PostSearchUrlCodec.maxNumberedPage
          ? page
          : null,
    );
  }
}

extension PostSearchUrlLinking on PostSearchUrl {
  /// Decodes a link-parser query map (already percent-decoded) into a search.
  /// Unknown keys are ignored; the app feed currently consumes `tags` only —
  /// the feed page size follows the user's per-page setting instead.
  static PostSearchUrl fromQuery(Map<String, String>? query) {
    String? read(List<String> keys) {
      for (final String key in keys) {
        final String? value = query?[key];
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final int? limit = int.tryParse(read(['limit', 'search[limit]']) ?? '');
    final int? page = int.tryParse(read(['page']) ?? '');
    return PostSearchUrl(
      tags: read(['tags', 'search[tags]']),
      limit: limit?.clamp(1, PostSearchUrlCodec.maxLimit),
      page:
          page != null &&
              page >= 1 &&
              page <= PostSearchUrlCodec.maxNumberedPage
          ? page
          : null,
    );
  }

  /// The initial tag string for a feed opened from this search.
  String? toParamsTags() => (tags ?? '').isEmpty ? null : tags;
}
