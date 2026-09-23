import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';
import '../../../env.dart';

/**
 * 待制作餐配送订单
 */
class AwaitingPreparationMealDeliveryOrderController extends GetxController {
  static AwaitingPreparationMealDeliveryOrderController get to => Get.find();

  /// 待制作状态的 key（对应 meal_delivery_order.status）
  static const String awaitingPreparationStatus = 'awaiting_preparation';

  final RxList<MealDeliveryOrder> awaitingPreparationMealDeliveryOrders =
      RxList();
  final RxInt count = 0.obs;

  final MealDeliveryOrderRepository _repository = Get.find();

  // 每页数据量
  int pageSize = 20;

  // 当前页码（从 0 开始）
  int currentPage = 0;

  // 是否有更多数据
  bool hasMore = true;

  /**
   * 获取待制作餐配送列表
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

      // 门店归属过滤（merchant_id）+ 状态过滤都写在数据层，
      // 并一次把 meal / meal_dish / dish_sku 嵌套查回来，item 不用再逐个查餐品
      final List<MealDeliveryOrder> result =
          await _repository.fetchByMerchant(
        merchantId: merchantId,
        status: awaitingPreparationStatus,
        page: newPage,
        pageSize: pageSize,
      );

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        awaitingPreparationMealDeliveryOrders.assignAll(result);
      } else {
        awaitingPreparationMealDeliveryOrders.addAll(result);
      }

      // 总数只在刷新（或首次加载）时取一次：上拉加载更多不会改变总数，省一个请求
      if (isRefresh || count.value == 0) {
        count.value = await _repository.countByMerchant(
          merchantId: merchantId,
          status: awaitingPreparationStatus,
        );
      }

      this.currentPage = newPage;
    } on ShowableException {
      rethrow;
    } catch (e) {
      print("fetchAwaitingPreparationMealDeliveryOrders, fail, $e");
      throw ShowableException('获取订单失败，未知错误！');
    }
  }

  Future<int> getCountFromRemote() async {
    try {
      // 正常取登录用户对应的店铺；未登录时可用 DEBUG_MERCHANT_ID 兜底（仅调试）
      final merchantId =
          MerchantController.to.merchant.value?.id ?? Env.debugMerchantId;
      if (merchantId == null) throw ShowableException('商家未登录！');

      final int total = await _repository.countByMerchant(
        merchantId: merchantId,
        status: awaitingPreparationStatus,
      );
      count.value = total;
      return total;
    } on ShowableException {
      rethrow;
    } catch (e) {
      print("getCountFromRemote, fail, $e");
      throw ShowableException('获取订单数失败，未知错误！');
    }
  }
}
