import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/dispatch_result.dart';
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

/**
 * 派单（呼叫骑手）
 *
 * 调用 Supabase Edge Function `dispatch-delivery-order`。
 *
 * ⚠️ 这个接口会产生真实费用：每成功一次都会在快递100 侧创建一笔真实运力订单并扣费。
 * 因此调用方必须先做二次确认，任何情况下都不要自动重试。
 *
 * [mealDeliveryOrder] 要派单的配送订单。
 * 只把它的 id 发给服务端（地址/金额由服务端查库组装，不接受客户端传入），
 * 成功后失效它的缓存。
 *
 * 成功返回 [DispatchResult]；失败抛 [ShowableException]（message 可直接展示给用户）
 */
Future<DispatchResult> dispatchDeliveryOrderByRemote(
  MealDeliveryOrder mealDeliveryOrder,
) async {
  // 只把「网络调用」放进 try：下面解析 data 时自己抛的 ShowableException
  // 不能被 catch (e, st) 抓住重新包装成「未知错误」
  final FunctionResponse response;
  try {
    response = await supabase.functions.invoke(
      'dispatch-delivery-order',
      // 调用方（logic 层）已校验过 id 非空
      body: {'meal_delivery_order_id': mealDeliveryOrder.id ?? ""},
    );
  } on FunctionException catch (e) {
    // 非 2xx：业务错误、网关错误都在异常里
    throw ShowableException(buildDispatchErrorMessage(e));
  } catch (e, st) {
    // 网络断了、TLS 失败等
    print("dispatchDeliveryOrderByRemote, fail, $e, $st");
    throw ShowableException('😂 派单失败，请检查网络后重试！');
  }

  // 走到这里一定是 2xx：派单已真实下发，配送单状态被改成 awaiting_delivery
  // 和 updateMealDeliveryOrderByRemote 同理，必须失效缓存，
  // 否则按 recipe_order_id 查回来的还是派单前的旧状态
  final recipeOrderId = mealDeliveryOrder.recipeOrderId;
  if (recipeOrderId != null &&
      Get.isRegistered<MealDeliveryOrderRepository>()) {
    Get.find<MealDeliveryOrderRepository>().clearCacheFor(recipeOrderId);
  }

  final data = response.data;
  if (data is! Map) {
    throw ShowableException('派单失败：服务端返回格式异常！');
  }
  return DispatchResult.fromJson(Map<String, dynamic>.from(data));
}

/**
 * 把 FunctionException 翻译成一句能直接展示给商家的中文
 */
String buildDispatchErrorMessage(FunctionException e) {
  final details = e.details;
  if (details is Map) {
    final error = details['error'];
    // ⚠️ 危险状态：真实单已发出、已扣费，只是本地没落库成功。
    // 此时绝不能提示「失败」——商家会再点一次，而服务端幂等靠的是
    // provider_order_id，此刻根本没落库，拦不住，会再发一笔真实单、再扣一次费。
    if (e.status == 500 && error is String && error.contains('落库失败')) {
      return '⚠️ 运力单已发出但落库失败！\n请勿重复派单，立即联系技术核对！';
    }
    // 函数返回的错误在 error 字段；网关拦截的只有 message 字段
    final message = error ?? details['message'];
    if (message is String) {
      final detail = details['detail'];
      return detail == null ? message : '$message（$detail）';
    }
  }
  return '派单失败（HTTP ${e.status}）';
}
