import 'package:dio/dio.dart';
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

  Future<User> _get(String lookup, {CancelToken? cancelToken}) => dio
      .get('/users/$lookup.json', cancelToken: cancelToken)
      .then((response) => E621User.fromJson(response.data));

  /// Fetches multiple users in one request. The endpoint accepts up to 320
  /// comma separated ids in `search[id]`; ids without a match are simply
  /// absent from the result.
  Future<List<User>> getMany({required List<int> ids}) => dio
      .get(
        '/users.json',
        queryParameters: {
          'search[id]': ids.join(','),
          'limit': ids.length.clamp(1, 320),
        },
      )
      .then(
        (response) => [
          for (final data in response.data as List) E621User.fromJson(data),
        ],
      );
}
