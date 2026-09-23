import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal.dart';

abstract class MealCacheDS {
  Meal? getOneById(String id);

  /**
   * 添加1个Meal通过id
   * [id] meal的id
   * [meal] 要添加的meal
   * [ttl]  Time-To-Live，生存时间，到时间后就移除缓存
   */
  void setOneById(String id, Meal meal, {Duration? ttl});
}

class MealCacheDSImpl implements MealCacheDS {
  final _cache = <String, Meal>{};

  @override
  Meal? getOneById(String id) {
    return _cache[id];
  }

  @override
  void setOneById(String id, Meal meal, {Duration? ttl}) {
    _cache[id] = meal;
    if (ttl != null) Future.delayed(ttl, () => _cache.remove(id));
  }
}
