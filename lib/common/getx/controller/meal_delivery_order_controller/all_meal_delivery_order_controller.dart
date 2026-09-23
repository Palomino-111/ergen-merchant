import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';

/**
 * 全部餐配送订单
 */
class AllMealDeliveryOrderController extends GetxController {
  static AllMealDeliveryOrderController get to => Get.find();
  final RxList<MealDeliveryOrder> allMealDeliveryOrders = RxList();

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
          .order('delivery_time', ascending: false)
          .range(offset, offset + pageSize - 1);
      final result = response.map((e) => MealDeliveryOrder.fromJson(e));

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        allMealDeliveryOrders.assignAll(result);
      } else {
        allMealDeliveryOrders.addAll(result);
      }

      this.currentPage = newPage;
    } catch (e) {
      print("fetchAllMealDeliveryOrders, fail, $e");
      throw ShowableException('获取订单失败，未知错误！');
    }
  }
}
