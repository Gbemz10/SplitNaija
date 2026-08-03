import '../models/models.dart';
import 'api_client.dart';

class ActivityService {
  ActivityService(this._api);
  final ApiClient _api;

  /// The merged expenses + settlements feed for the Activity tab, newest
  /// first. One call — the backend does the cross-group aggregation.
  Future<List<ActivityItem>> listActivity({int limit = 50}) async {
    final data = await _api.getList('/activity?limit=$limit');
    return data.map((a) => ActivityItem.fromJson(a as Map<String, dynamic>)).toList();
  }
}
