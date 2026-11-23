import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

/// 统一的网络异常。
///
/// 设计目标：把 dio 的底层错误（超时/连接/HTTP 状态码/业务 code）
/// 收敛成一种类型，UI 只关心 `userMessage` 与 `retryable`。
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.uri,
    this.retryable = false,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? uri;
  final bool retryable;
  final Object? cause;

  /// 给用户看的短句（不暴露堆栈与内部路径）。
  String get userMessage {
    if (message.isNotEmpty) return message;
    if (statusCode == 404) return '内容不存在';
    if (statusCode == 412) return '请求被拒绝（风控），请稍后重试';
    if (statusCode == 429) return '请求太频繁，请稍后再试';
    if (statusCode != null && statusCode! >= 500) return '服务端异常，请稍后重试';
    return '网络请求失败';
  }

  @override
  String toString() =>
      'ApiException($message, status=$statusCode, uri=$uri)';
}

/// HTTP 客户端：统一超时、UA、重试、日志与错误映射。
///
/// 约定：
/// - 只暴露 `getJson` / `postJson` / `getBytes`，业务不直接拿 dio；
/// - 重试仅针对「超时 / 连接失败 / 5xx / 429」，业务错误不重试；
/// - 每个请求写一条 debug 日志（耗时 + 状态），方便排查。
class ApiClient {
  ApiClient({
    required this.logger,
    Dio? dio,
    Map<String, String> defaultHeaders = const {},
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 600),
  })  : defaultHeaders = Map.unmodifiable(defaultHeaders),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 8),
              responseType: ResponseType.plain,
              headers: {
                HttpHeaders.userAgentHeader:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/131.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              },
            )) {
    _dio.options.headers.addAll(this.defaultHeaders);
  }

  final AppLogger logger;
  final Dio _dio;
  final Map<String, String> defaultHeaders;
  final int maxAttempts;
  final Duration retryDelay;

  int _seq = 0;

  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? tag,
  }) =>
      _request(
        () => _dio.get<String>(
          url,
          queryParameters: query,
          options: Options(headers: headers),
        ),
        tag: tag ?? 'api',
        url: url,
      );

  Future<Map<String, dynamic>> postJson(
    String url, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? tag,
  }) =>
      _request(
        () => _dio.post<String>(
          url,
          data: body,
          queryParameters: query,
          options: Options(headers: headers),
        ),
        tag: tag ?? 'api',
        url: url,
      );

  Future<List<int>> getBytes(String url, {Map<String, String>? headers}) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );
      return res.data ?? const <int>[];
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<String>> Function() send, {
    required String tag,
    required String url,
  }) async {
    final id = ++_seq;
    ApiException? last;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final sw = Stopwatch()..start();
      try {
        final res = await send();
        sw.stop();
        logger.debug(
          'http',
          '#$id $tag ${res.statusCode} ${sw.elapsedMilliseconds}ms '
              '${res.requestOptions.uri}',
        );

        final raw = res.data ?? '';
        if (raw.trim().isEmpty) {
          throw ApiException('响应为空', uri: url, retryable: true);
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw ApiException('响应格式异常', uri: url);
        }
        return decoded;
      } on DioException catch (e) {
        sw.stop();
        last = _mapDioError(e);
        logger.warn(
          'http',
          '#$id $tag 第 $attempt/$maxAttempts 次失败（${sw.elapsedMilliseconds}ms）：'
              '${last.message}',
        );
        if (!last.retryable || attempt == maxAttempts) throw last;
        await Future<void>.delayed(retryDelay * attempt);
      } on ApiException catch (e) {
        last = e;
        if (!e.retryable || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      } on FormatException catch (e) {
        throw ApiException('响应解析失败', uri: url, cause: e);
      }
    }

    throw last ?? ApiException('请求失败', uri: url);
  }

  ApiException _mapDioError(DioException e) {
    final uri = e.requestOptions.uri.toString();
    final status = e.response?.statusCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException('请求超时', uri: uri, retryable: true, cause: e);
      case DioExceptionType.connectionError:
        return ApiException('连接失败，请检查网络或代理',
            uri: uri, retryable: true, cause: e);
      default:
        break;
    }

    if (status != null) {
      return ApiException(
        status >= 500 ? '服务端异常（$status）' : '请求失败（$status）',
        statusCode: status,
        uri: uri,
        retryable: status >= 500 || status == 429,
        cause: e,
      );
    }
    return ApiException('网络异常：${e.message ?? e.type.name}',
        uri: uri, cause: e);
  }
}
