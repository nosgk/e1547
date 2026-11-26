import 'package:e1547/post/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostSearchUrlCodec', () {
    test('encodes the canonical web URL of a search', () {
      expect(
        PostSearchUrlCodec.encode(const PostParams(tags: 'dragon canine')),
        'https://e621.net/posts?tags=dragon+canine',
      );
      expect(
        PostSearchUrlCodec.encode(const PostParams(tags: 'score:>=20')),
        'https://e621.net/posts?tags=score%3A%3E%3D20',
      );
    });

    test('keeps the URL clean for default page sizes and first pages', () {
      final url = PostSearchUrlCodec.encode(
        const PostParams(tags: 'dragon'),
        limit: 75,
        page: 1,
      );
      expect(url, 'https://e621.net/posts?tags=dragon');
    });

    test('clamps the emitted limit into the legal range', () {
      final url = PostSearchUrlCodec.encode(
        const PostParams(tags: 'dragon'),
        limit: 9999,
      );
      expect(url, contains('limit=320'));
    });

    test('parses classic and search-spelled web URLs', () {
      final classic = PostSearchUrlCodec.parse(
        Uri.parse('https://e621.net/posts?tags=dragon+canine&limit=75'),
      );
      expect(classic, isNotNull);
      expect(classic!.tags, 'dragon canine');
      expect(classic.limit, 75);

      final modern = PostSearchUrlCodec.parse(
        Uri.parse('https://e926.net/posts?search[tags]=rating%3As'),
      );
      expect(modern, isNotNull);
      expect(modern!.tags, 'rating:s');
    });

    test('clamps limit and drops illegal numbered pages on parse', () {
      final clamped = PostSearchUrlCodec.parse(
        Uri.parse('https://e621.net/posts?tags=dragon&limit=9999'),
      );
      expect(clamped!.limit, 320);

      final page = PostSearchUrlCodec.parse(
        Uri.parse('https://e621.net/posts?tags=dragon&page=900'),
      );
      expect(page!.page, isNull);

      final cursor = PostSearchUrlCodec.parse(
        Uri.parse('https://e621.net/posts?tags=dragon&page=42'),
      );
      expect(cursor!.page, 42);
    });

    test('rejects non-post-search URLs', () {
      expect(
        PostSearchUrlCodec.parse(Uri.parse('https://e621.net/pools')),
        isNull,
      );
      expect(
        PostSearchUrlCodec.parse(Uri.parse('https://example.com/posts')),
        isNull,
      );
    });

    test('link query maps decode the same way', () {
      final search = PostSearchUrlCodec.parseLink({
        'tags': 'dragon',
        'limit': '75',
      });
      expect(search.tags, 'dragon');
      expect(search.limit, 75);
      expect(search.toParamsTags(), 'dragon');
      expect(PostSearchUrlCodec.parseLink(null).toParamsTags(), isNull);
    });
  });
}
