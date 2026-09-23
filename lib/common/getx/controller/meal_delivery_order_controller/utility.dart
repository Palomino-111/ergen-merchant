import '../../../../main.dart';
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
  } catch (e, st) {
    print("updateMealDeliveryOrderByRemote, fail, $e, $st");
    throw ShowableException('😂 更新失败，未知错误！');
  }
}
