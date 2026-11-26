import 'package:dio/dio.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/user/user.dart';

class UserClient {
  UserClient({required this.dio});

  final Dio dio;

  // Technically missing users()
  Future<User> get({required int id, CancelToken? cancelToken}) =>
      _get(id.toString(), cancelToken: cancelToken);

  /// `/users/<lookup>.json` only accepts a numeric id. A name is resolved
  /// through the index (`search[name_matches]` is an exact match) and then
  /// loaded by id so the response includes the full profile. Unknown names
  /// return null instead of a 404.
  Future<User?> getByName({
    required String name,
    CancelToken? cancelToken,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (int.tryParse(trimmed) != null) {
      try {
        return await _get(trimmed, cancelToken: cancelToken);
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) return null;
        rethrow;
      }
    }
    final listed = await dio.get(
      '/users.json',
      queryParameters: {'search[name_matches]': trimmed, 'limit': 1},
      cancelToken: cancelToken,
    );
    final rows = listed.data;
    if (rows is! List || rows.isEmpty) return null;
    final id = (rows.first as Map)['id'];
    if (id is! int) return E621User.fromJson(rows.first);
    try {
      return await _get('$id', cancelToken: cancelToken);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<PartialUser>> page({
    int? page,
    int? limit,
    QueryMap? query,
    CancelToken? cancelToken,
  }) => dio
      .get(
        '/users.json',
        queryParameters: {'page': page, 'limit': limit, ...?query},
        cancelToken: cancelToken,
      )
      .then(unwrapRailsArray)
      .then(
        (response) => (response.data as List)
            .map<PartialUser>(E621User.partialFromJson)
            .toList(),
      );

  Future<List<PartialUser>> byIds({
    required List<int> ids,
    CancelToken? cancelToken,
  }) => page(
    limit: ids.length,
    query: {'search[id]': ids.join(',')},
    cancelToken: cancelToken,
  );

  Future<List<PartialUser>> search({
    required String name,
    int? limit,
    CancelToken? cancelToken,
  }) => page(
    limit: limit,
    query: {
      'search[name_matches]': '$name*',
      'search[order]': 'post_upload_count',
    },
    cancelToken: cancelToken,
  );

  Future<User> _get(String lookup, {CancelToken? cancelToken}) => dio
      .get('/users/$lookup.json', cancelToken: cancelToken)
      .then((response) => E621User.fromJson(response.data));
}
