import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../domain/use_cases/favorite_change_watcher.dart';

class FavoriteChangesApi {
  final Dio dio;
  final CancelToken cancelToken = CancelToken();
  FavoriteChangesApi(this.dio);

  Future<FavoriteChange> poll(String? cursor) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/playlists/favorites/changes',
      queryParameters: {if (cursor != null) 'cursor': cursor},
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 35)),
    );
    final data = response.data;
    if (data == null ||
        data['cursor'] is! String ||
        (data['cursor'] as String).isEmpty ||
        data['changed'] is! bool) {
      throw const FormatException('Invalid favorite change notification');
    }
    return FavoriteChange(data['cursor'] as String, data['changed'] as bool);
  }
}
