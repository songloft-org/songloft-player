import 'package:dio/dio.dart';

import '../../l10n/l10n_holder.dart';

/// 基础 API 异常类
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  /// 从 DioException 创建 ApiException
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message:
              l10nOrNull?.coreErrorConnectionTimeout(_targetOf(e)) ??
              '无法连接到 ${_targetOf(e)}（连接超时）。'
                  '请检查：①后端服务是否运行 ②URL 与端口是否正确 '
                  '③若通过 ZeroTier/VPN 访问，请确认 VPN 已连接并启用「全局路由」',
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message:
              l10nOrNull?.coreErrorConnectionFailed(_targetOf(e)) ??
              '无法连接到 ${_targetOf(e)}。'
                  '请检查 URL 是否正确；若通过 ZeroTier/VPN 访问，请确认 VPN 已启用',
        );
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: l10nOrNull?.coreErrorBadCertificate ?? '证书验证失败',
        );
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(e.response);
      case DioExceptionType.cancel:
        return ApiException(
          message: l10nOrNull?.coreErrorRequestCancelled ?? '请求已取消',
        );
      case DioExceptionType.unknown:
        return NetworkException(
          message:
              e.message ?? l10nOrNull?.coreErrorUnknownNetwork ?? '未知网络错误',
        );
      // Dio 5.10 adds transformTimeout; keep compiling with older Dio versions.
      // ignore: unreachable_switch_default
      default:
        if (e.type.name == 'transformTimeout') {
          return NetworkException(
            message:
                l10nOrNull?.coreErrorConnectionTimeout(_targetOf(e)) ??
                '无法连接到 ${_targetOf(e)}（连接超时）。'
                    '请检查：①后端服务是否运行 ②URL 与端口是否正确 '
                    '③若通过 ZeroTier/VPN 访问，请确认 VPN 已连接并启用「全局路由」',
          );
        }
        return NetworkException(
          message:
              e.message ?? l10nOrNull?.coreErrorUnknownNetwork ?? '未知网络错误',
        );
    }
  }

  /// 从 DioException 提取目标地址用于错误提示（优先 baseUrl，回退完整 uri）
  static String _targetOf(DioException e) {
    final base = e.requestOptions.baseUrl;
    if (base.isNotEmpty) return base;
    return e.requestOptions.uri.toString();
  }

  /// 从响应错误创建 ApiException
  /// 后端返回格式: {"error": "...", "detail": "..."}
  factory ApiException.fromResponse(Response? response) {
    if (response == null) {
      return ApiException(
        message: l10nOrNull?.coreErrorNoResponse ?? '服务器无响应',
      );
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // 尝试解析后端错误信息
    String message = l10nOrNull?.coreErrorRequestFailed ?? '请求失败';
    if (data is Map<String, dynamic>) {
      message =
          data['error'] as String? ??
          data['detail'] as String? ??
          data['message'] as String? ??
          (l10nOrNull?.coreErrorRequestFailed ?? '请求失败');
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    // 根据状态码返回特定异常类型
    switch (statusCode) {
      case 401:
        return UnauthorizedException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case 403:
        return ForbiddenException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case 404:
        return NotFoundException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      default:
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
    }
  }

  @override
  String toString() => 'ApiException: $message (statusCode: $statusCode)';
}

/// 未授权异常（401）
class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message, super.statusCode = 401, super.data})
    : super(
        message:
            message ?? l10nOrNull?.coreErrorUnauthorized ?? '登录已过期，请重新登录',
      );
}

/// 禁止访问异常（403）
class ForbiddenException extends ApiException {
  ForbiddenException({String? message, super.statusCode = 403, super.data})
    : super(message: message ?? l10nOrNull?.coreErrorForbidden ?? '没有权限访问');
}

/// 未找到异常（404）
class NotFoundException extends ApiException {
  NotFoundException({String? message, super.statusCode = 404, super.data})
    : super(message: message ?? l10nOrNull?.coreErrorNotFound ?? '请求的资源不存在');
}

/// 网络异常
class NetworkException extends ApiException {
  NetworkException({String? message, super.statusCode, super.data})
    : super(message: message ?? l10nOrNull?.errorNetworkFailed ?? '网络连接失败');
}

/// 服务器异常（5xx）
class ServerException extends ApiException {
  ServerException({String? message, super.statusCode, super.data})
    : super(message: message ?? l10nOrNull?.coreErrorServer ?? '服务器错误，请稍后重试');
}
