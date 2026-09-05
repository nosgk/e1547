import 'package:dio/dio.dart';
import 'package:e1547/user/user.dart';

class UserClient {
  UserClient({required this.dio});

  final Dio dio;

  // Technically missing users()
  Future<User> get({required int id, CancelToken? cancelToken}) =>
      _get(id.toString(), cancelToken: cancelToken);

  Future<User> getByName({required String name, CancelToken? cancelToken}) =>
      _get(name, cancelToken: cancelToken);

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
