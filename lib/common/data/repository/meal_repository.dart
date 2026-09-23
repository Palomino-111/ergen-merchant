import '../../models/meal.dart';
import '../data_source/cache/meal_cache_ds.dart';
import '../data_source/remote/meal_remote_ds.dart';

abstract class MealRepository {
  Future<Meal?> getOneById(String id);
}

class MealRepositoryImpl implements MealRepository {
  final MealRemoteDS _remote;
  final MealCacheDS _cache;

  MealRepositoryImpl({
    required MealRemoteDS remote,
    required MealCacheDS cache,
  })  : _remote = remote,
        _cache = cache;

  @override
  Future<Meal?> getOneById(String id) async {
    // 1. 内存缓存命中
    final cached = _cache.getOneById(id);
    if (cached != null) return cached;

    // 2. 远程拉取
    final meal = await _remote.getOneById(id);

    // 3. 回写本地 + 缓存
    _cache.setOneById(id, meal);
    return meal;
  }
}
