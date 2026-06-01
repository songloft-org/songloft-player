import 'package:dio/dio.dart';

/// 基础 API 异常类
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  /// 从 DioException 创建 ApiException
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: '无法连接到 ${_targetOf(e)}（连接超时）。'
              '请检查：①后端服务是否运行 ②URL 与端口是否正确 '
              '③若通过 ZeroTier/VPN 访问，请确认 VPN 已连接并启用「全局路由」',
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: '无法连接到 ${_targetOf(e)}。'
              '请检查 URL 是否正确；若通过 ZeroTier/VPN 访问，请确认 VPN 已启用',
        );
      case DioExceptionType.badCertificate:
        return NetworkException(message: '证书验证失败');
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(e.response);
      case DioExceptionType.cancel:
        return ApiException(message: '请求已取消');
      case DioExceptionType.unknown:
        return NetworkException(
          message: e.message ?? '未知网络错误',
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
      return ApiException(message: '服务器无响应');
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // 尝试解析后端错误信息
    String message = '请求失败';
    if (data is Map<String, dynamic>) {
      message = data['error'] as String? ??
          data['detail'] as String? ??
          data['message'] as String? ??
          '请求失败';
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
  UnauthorizedException({
    super.message = '登录已过期，请重新登录',
    super.statusCode = 401,
    super.data,
  });
}

/// 禁止访问异常（403）
class ForbiddenException extends ApiException {
  ForbiddenException({
    super.message = '没有权限访问',
    super.statusCode = 403,
    super.data,
  });
}

/// 未找到异常（404）
class NotFoundException extends ApiException {
  NotFoundException({
    super.message = '请求的资源不存在',
    super.statusCode = 404,
    super.data,
  });
}

/// 网络异常
class NetworkException extends ApiException {
  NetworkException({
    super.message = '网络连接失败，请检查网络',
    super.statusCode,
    super.data,
  });
}

/// 服务器异常（5xx）
class ServerException extends ApiException {
  ServerException({
    super.message = '服务器错误，请稍后重试',
    super.statusCode,
    super.data,
  });
}
