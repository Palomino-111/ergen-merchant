import 'package:zheergen_merchant_end/common/models/dispatch_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/dispatch_result.dart';    
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

Future<DispatchResult> dispatchDeliveryOrderByRemote(String orderId) async{
  final FunctionResponse response;
 try {
    response = await supabase.functions.invoke(
      'dispatch-delivery-order',
      body: {'meal_delivery_order_id': orderId},
    );
  } on FunctionException catch (e) {
    throw ShowableException(buildDispatchErrorMessage(e));
  } catch (e, st) {
    print("dispatchDeliveryOrderByRemote, fail, $e, $st");
    throw ShowableException('😂 派单失败，请检查网络后重试！');
  }

  final data = response.data;
  if (data is! Map) {
    throw ShowableException('派单失败：服务端返回格式异常！');
  }
  return DispatchResult.fromJson(Map<String, dynamic>.from(data));
}

String buildDispatchErrorMessage(FunctionException e) {
  final details = e.details;
  if (details is Map) {
    final error = details['error'];
    // ⚠️ 危险状态：真实单已发出、已扣费，只是本地没落库成功
    if (e.status == 500 && error is String && error.contains('落库失败')) {
      return '⚠️ 运力单已发出但落库失败！\n请勿重复派单，立即联系技术核对！';
    }
    // 函数返回的错误在 error 字段；网关拦截的在 message 字段
    final message = error ?? details['message'];
    if (message is String) {
      final detail = details['detail'];
      return detail == null ? message : '$message（$detail）';
    }
  }
  return '派单失败（HTTP ${e.status}）';
}
