import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/dish_sku.dart';
import '../../../models/meal.dart';

abstract class MealRemoteDS {
  Future<Meal> getOneById(String id);
}

class MealRemoteDSImpl implements MealRemoteDS {
  @override
  Future<Meal> getOneById(String id) async {
    try {
      // 获取meal数据
      final mealData = await supabase.from('meal').select('''
            *,
            meal_dishes: meal_dish!meal_id (
              *,
              dish_sku: dish_sku_id (*)
            )
          ''').eq('id', id).single();
      // 获取dishSkus
      final mealDishesData = mealData['meal_dishes'] as List? ?? [];
      final dishSkus = mealDishesData.map((mealDishData) {
        return DishSku.fromJson(mealDishData['dish_sku']);
      }).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Meal.fromJson(mealData)..dishSkus = dishSkus;
    } catch (e, st) {
      print("getOneById, fail, $e, $st");
      throw ShowableException('获取健康餐信息失败，未知错误！');
    }
  }
}
