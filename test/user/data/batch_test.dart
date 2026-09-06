import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/user/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_support/client.dart';
import '../../_support/fake_e621.dart';
import '../../_support/fixtures.dart';
import '../../_support/harness.dart';

void main() {
  late FakeE621 fake;
  late UserClient client;

  setUpAll(initializeTestApp);

  setUp(() async {
    fake = await FakeE621.start();
    final dio = dioFor(fake);
    final cache = CachedQuery.asNewInstance();
    dio.queryCache = cache;
    dio.queryIdentity = 1;
    client = UserClient(dio: dio);
  });

  tearDown(() => fake.stop());

  test('getMany fetches multiple users in one request', () async {
    final recorded = loadFixtureList('users.json').first;
    final id = recorded['id']! as int;

    final users = await client.getMany(ids: [id, id + 999999]);

    expect(users.map((user) => user.id), contains(id));
  });

  test('batcher writes requested users into the query cache', () async {
    final recorded = loadFixtureList('users.json').first;
    final id = recorded['id']! as int;

    final query = client.useGet(id: id, vendored: true);
    expect(query.state.data, isNull);

    client.batcher.request(id);
    // The coalescing window is 250ms; allow the flush to complete.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(query.state.data, isNotNull);
    expect(query.state.data!.id, id);
  });
}
