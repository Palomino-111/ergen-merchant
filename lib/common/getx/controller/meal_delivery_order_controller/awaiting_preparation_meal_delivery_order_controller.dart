import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';

/**
 * 待制作餐配送订单
 */
class AwaitingPreparationMealDeliveryOrderController extends GetxController {
  static AwaitingPreparationMealDeliveryOrderController get to => Get.find();
  final RxList<MealDeliveryOrder> awaitingPreparationMealDeliveryOrders =
      RxList();
  final RxInt count = 0.obs;

  // 每页数据量
  int pageSize = 20;

  // 当前页码（从 0 开始）
  int currentPage = 0;

  // 是否有更多数据
  bool hasMore = true;

  /**
   * 获取餐配送列表
   * [isRefresh]，是否是刷新，true表示刷新，清空列表，重新从第一页数据获取，false表示加载下一页数据
   */
  Future<void> fetchMealDeliveryOrders({
    // 是否是刷新 下拉刷新相当于获取第一页数据
    bool isRefresh = false,
  }) async {
    try {
      final merchantId = MerchantController.to.merchant.value?.id;
      if (merchantId == null) throw ShowableException('商家未登录！');

      int newPage = isRefresh ? 0 : currentPage + 1;
      int offset = newPage * pageSize;

      final response = await supabase
          .from('meal_delivery_order')
          .select()
          .eq('merchant_id', merchantId)
          .eq('status', 'awaiting_preparation')
          .order('delivery_time', ascending: false)
          .range(offset, offset + pageSize - 1)
          .count(CountOption.estimated);
      count.value = response.count;
      final result = response.data.map((e) => MealDeliveryOrder.fromJson(e));

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        awaitingPreparationMealDeliveryOrders.assignAll(result);
      } else {
        awaitingPreparationMealDeliveryOrders.addAll(result);
      }

      this.currentPage = newPage;
    } catch (e) {
      print("fetchAwaitingPreparationMealDeliveryOrders, fail, $e");
      throw ShowableException('获取订单失败，未知错误！');
    }
  }

  Future<int> getCountFromRemote() async {
    try {
      final merchantId = MerchantController.to.merchant.value?.id;
      if (merchantId == null) throw ShowableException('商家未登录！');

      final response = await supabase
          .from('meal_delivery_order')
          .select()
          .eq('merchant_id', merchantId)
          .eq('status', 'awaiting_preparation')
          .count(CountOption.estimated);
      count.value = response.count;
      return response.count;
    } catch (e) {
      print("getCountFromRemote, fail, $e");
      throw ShowableException('获取订单数失败，未知错误！');
    }
  }
}
