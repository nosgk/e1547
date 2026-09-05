import 'dart:math';

import 'package:dio/dio.dart';
import 'package:e1547/shared/shared.dart';

/// Retry handling for e621 API semantics.
///
/// - 429 / 503: rate limited. Idempotent GET requests are replayed with
///   exponential backoff, honoring `Retry-After` when present. POSTs are
///   never replayed, as they are not safe to repeat.
/// - 410: pagination past the last page. Fails immediately with a readable
///   message instead of a bare status code.
class E621RetryInterceptor extends Interceptor {
  E621RetryInterceptor(
    this.dio, {
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 8),
  });

  static const String _attemptsKey = '@e621_retry_attempts';

  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;

  Duration backoff(int attempt) {
    final Duration scaled = initialDelay * pow(2, attempt).toInt();
    return scaled > maxDelay ? maxDelay : scaled;
  }

  Duration? retryAfter(Headers? headers) {
    final String? value = headers?.value('retry-after');
    final int? seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null) return null;
    final Duration duration = Duration(seconds: seconds);
    return duration > maxDelay ? maxDelay : duration;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final Response<dynamic>? response = err.response;
    final int? code = response?.statusCode;
    final RequestOptions request = err.requestOptions;

    // Pagination past the last page (plain page numbers beyond the API cap).
    // Not an infrastructure error; retrying cannot fix it.
    if (code == 410) {
      handler.reject(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: response,
          error: 'You have reached the end of this content',
        ),
      );
      return;
    }

    final bool rateLimited = code == 429 || code == 503;
    final int attempts = request.extra[_attemptsKey] as int? ?? 0;
    final bool retryable =
        rateLimited &&
        attempts < maxRetries &&
        request.method.toUpperCase() == 'GET' &&
        !isCloudflareChallenge(response);

    if (!retryable) {
      handler.next(err);
      return;
    }

    request.extra[_attemptsKey] = attempts + 1;
    final Duration delay = retryAfter(response?.headers) ?? backoff(attempts);
    await Future<void>.delayed(delay);
    try {
      final Response<dynamic> retry = await dio.fetch(request);
      handler.resolve(retry);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
