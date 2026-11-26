import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/client.dart';
import '../../_support/fake_e621.dart';
import '../../_support/fixtures.dart';
import '../../_support/harness.dart';

void main() {
  late FakeE621 fake;
  late TagClient client;

  setUpAll(initializeTestApp);

  setUp(() async {
    fake = await FakeE621.start();
    final dio = dioFor(fake);
    dio.queryCache = CachedQuery.asNewInstance();
    dio.queryIdentity = 1;
    client = TagClient(dio: dio);
  });

  tearDown(() => fake.stop());

  test('maps a recorded tag onto the model', () async {
    final recorded = loadFixtureList('tags.json').first;

    final tag = (await client.page()).first;

    expect(tag.id, recorded['id']);
    expect(tag.name, recorded['name']);
    expect(tag.count, recorded['post_count']);
    expect(tag.category, recorded['category']);
  });

  test('skips a deleted alias for its consequent', () async {
    final recorded = loadFixtureList('tag_aliases.json').first;
    fake.state.tagAliases.insert(0, {
      ...recorded,
      'consequent_name': 'tag_gone',
      'status': 'deleted',
    });
    final String antecedent = recorded['antecedent_name']! as String;

    final alias = await client.aliases(
      query: {'search[antecedent_name]': antecedent},
    );

    expect(alias, recorded['consequent_name']);
    expect(
      fake.requests.last.query,
      containsPair('search[antecedent_name]', antecedent),
    );
  });

  test('reads the exact post count of an existing tag', () async {
    final recorded = loadFixtureList('tags.json').first;
    final tag = client.useCount(tag: recorded['name']! as String);

    await tag.fetch();

    expect(tag.state.data, recorded['post_count']);
  });

  test('reports no count for an unknown tag', () async {
    final tag = client.useCount(tag: 'no_such_tag_here');

    await tag.fetch();

    expect(tag.state.data, isNull);
  });
}
