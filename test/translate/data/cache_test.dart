import 'dart:convert';

import 'package:e1547/translate/data/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notified_preferences/notified_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'translation cache evicts least recently used entries, persists and '
    'clears',
    () async {
      final cache = TranslationCache.instance;
      await cache.ready;
      await cache.clear();

      cache.limit = 3;
      cache.put('a', '1');
      cache.put('b', '2');
      cache.put('c', '3');
      expect(cache.count, 3);

      // A hit refreshes recency: b becomes the most recent entry.
      expect(cache.get('b'), '2');

      // Two more entries evict the two least recently used (a and c);
      // the refreshed b survives.
      cache.put('d', '4');
      cache.put('e', '5');
      expect(cache.count, 3);
      expect(cache.get('a'), isNull);
      expect(cache.get('c'), isNull);
      expect(cache.get('b'), '2');
      expect(cache.get('d'), '4');
      expect(cache.get('e'), '5');

      // Entries are persisted (debounced write-back).
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString('translateCache')!)
              as Map<String, dynamic>;
      expect(stored['b'], '2');
      expect(stored.containsKey('c'), isFalse);

      // A limit of zero means unlimited.
      cache.limit = 0;
      for (var i = 0; i < 50; i++) {
        cache.put('k$i', 'v$i');
      }
      expect(cache.get('k0'), 'v0');
      expect(cache.get('b'), '2');

      // Clearing empties the cache and the stored preferences.
      await cache.clear();
      expect(cache.count, 0);
      expect(
        (await SharedPreferences.getInstance()).getString('translateCache'),
        isNull,
      );
    },
  );
}
