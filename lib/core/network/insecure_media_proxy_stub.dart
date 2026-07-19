/// Web 平台占位实现：不存在原生代理，直接返回原始 URL（浏览器自行处理 TLS）。
class InsecureMediaProxy {
  InsecureMediaProxy._();

  static final InsecureMediaProxy instance = InsecureMediaProxy._();

  /// web 无需代理，原样返回。
  Future<String> wrapHls(String url) async => url;
}
