import 'dart:async';

import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/dish_sku.dart';
import '../../../models/meal.dart';
import '../../../utility/network.dart';

abstract class MealRemoteDS {
  Future<Meal> getOneById(String id);
}

class MealRemoteDSImpl implements MealRemoteDS {
  @override
  Future<Meal> getOneById(String id) async {
    try {
      // 获取meal数据
      // 注意：这里用 `meal_dish!meal_id` 的 INNER JOIN 写法，meal 没有关联菜品时
      // 会查不到数据；配送单列表那条链路用的是 mapper 里的 LEFT JOIN 嵌套查询。
      final mealData = await withNetworkTimeout(
        supabase.from('meal').select('''
            *,
            meal_dishes: meal_dish!meal_id (
              *,
              dish_sku: dish_sku_id (*)
            )
          ''').eq('id', id).single(),
      );
      // 获取dishSkus
      final mealDishesData = mealData['meal_dishes'] as List? ?? [];
      final dishSkus = mealDishesData.map((mealDishData) {
        return DishSku.fromJson(mealDishData['dish_sku']);
      }).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Meal.fromJson(mealData)..dishSkus = dishSkus;
    } on TimeoutException catch (e) {
      print("getOneById, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("getOneById, fail, $e, $st");
      throw ShowableException('获取健康餐信息失败，未知错误！');
    }
  }
}
