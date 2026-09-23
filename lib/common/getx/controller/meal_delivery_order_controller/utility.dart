import 'package:get/get.dart';
import '../../../../main.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';

/**
 * 更新配送订单
 */
Future<void> updateMealDeliveryOrderByRemote(
  MealDeliveryOrder newMealDeliveryOrder,
) async {
  try {
    await supabase
        .from('meal_delivery_order')
        .update(newMealDeliveryOrder.toJson())
        .eq('id', newMealDeliveryOrder.id ?? "");

    // 写成功之后必须失效缓存：否则按 recipe_order_id 查回来的还是旧状态
    // （消费端就是漏了这一步，订单详情页得先手动 clear 才能拿到新数据）
    final recipeOrderId = newMealDeliveryOrder.recipeOrderId;
    if (recipeOrderId != null &&
        Get.isRegistered<MealDeliveryOrderRepository>()) {
      Get.find<MealDeliveryOrderRepository>().clearCacheFor(recipeOrderId);
    }
  } catch (e, st) {
    print("updateMealDeliveryOrderByRemote, fail, $e, $st");
    throw ShowableException('😂 更新失败，未知错误！');
  }
}
