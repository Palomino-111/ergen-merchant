import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';
import '../../../env.dart';
import 'realtime_utility.dart';

/**
 * 全部餐配送订单
 */
class AllMealDeliveryOrderController extends GetxController {
  static AllMealDeliveryOrderController get to => Get.find();
  final RxList<MealDeliveryOrder> allMealDeliveryOrders = RxList();

  final MealDeliveryOrderRepository _repository = Get.find();

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
      // 正常取登录用户对应的店铺；未登录时可用 DEBUG_MERCHANT_ID 兜底（仅调试）
      final merchantId =
          MerchantController.to.merchant.value?.id ?? Env.debugMerchantId;
      if (merchantId == null) throw ShowableException('商家未登录！');

      int newPage = isRefresh ? 0 : currentPage + 1;

      // 门店归属过滤写在数据层（merchant_id），并一次把 meal / meal_dish / dish_sku
      // 嵌套查回来，item 不用再逐个查餐品
      final List<MealDeliveryOrder> result =
          await _repository.fetchByMerchant(
        merchantId: merchantId,
        page: newPage,
        pageSize: pageSize,
      );

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        allMealDeliveryOrders.assignAll(result);
      } else {
        allMealDeliveryOrders.addAll(result);
      }

      this.currentPage = newPage;
    } on ShowableException {
      rethrow;
    } catch (e) {
      print("fetchAllMealDeliveryOrders, fail, $e");
      throw ShowableException('获取订单失败，未知错误！');
    }
  }

  /**
   * 用一条数据库行更新列表里对应的那一单（局部更新，绝不整表刷新）
   *
   * 数据来源有两条，拿到的都是 `meal_delivery_order` 的表行：
   * - Realtime 推送的 newRecord（服务端一改状态，界面立刻跟着变）
   * - 回到前台时按 id 批量重查的结果
   *
   * 找不到就什么都不做：订阅收到的是**全店**的变更，商家当前没加载到的单
   * （不在已翻到的页里）不该凭空插进列表尾部，那会把分页顺序搞乱。
   */
  void applyRealtimeUpdate(Map<String, dynamic> row) {
    final String? id = row['id'] as String?;
    if (id == null) {
      return;
    }
    final int index = allMealDeliveryOrders.indexWhere(
      (order) => order.id == id,
    );
    if (index < 0) {
      return;
    }
    allMealDeliveryOrders[index] = mergeDeliveryOrderRow(
      allMealDeliveryOrders[index],
      row,
    );
  }
}
