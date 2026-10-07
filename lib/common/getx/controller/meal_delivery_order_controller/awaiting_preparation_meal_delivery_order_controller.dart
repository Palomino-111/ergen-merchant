import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';
import '../../../env.dart';
import 'realtime_utility.dart';

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

  /**
   * 用一条数据库行更新待制作列表里对应的那一单
   *
   * 数据来源有三条，最终都走这里，所以「同一个状态变化」只会生效一次：
   * - Realtime 推送的 newRecord
   * - 回到前台时按 id 批量重查的结果
   * - 派单成功后本地的乐观更新（走 [applyDispatched]）
   *
   * 规则：这个列表只该有「待制作」状态的单，状态一旦不是待制作就**立刻移除**
   * 并同步角标，不用等商家下拉刷新。
   *
   * 幂等性靠「移除之后就再也找不到这一条」实现：晚到的那条路径会因为
   * indexWhere 返回 -1 直接退出，所以角标不会被重复扣减。
   */
  void applyRealtimeUpdate(Map<String, dynamic> row) {
    final String? id = row['id'] as String?;
    if (id == null) {
      return;
    }
    final int index = awaitingPreparationMealDeliveryOrders.indexWhere(
      (order) => order.id == id,
    );
    // 不在待制作列表里（没加载到 / 已经被移除）就什么都不做。
    // 尤其是**不能**把状态变成待制作的单插进来，那属于新订单到来的场景。
    if (index < 0) {
      return;
    }

    final String? newStatus = row['status'] as String?;
    if (newStatus != null && newStatus != awaitingPreparationStatus) {
      awaitingPreparationMealDeliveryOrders.removeAt(index);
      // 本地这份还是待制作，说明这次移除是账号上第一次看到的状态变化，
      // 服务端的待制作总数也确实少了一个，角标跟着减
      if (count.value > 0) {
        count.value -= 1;
      }
      return;
    }

    awaitingPreparationMealDeliveryOrders[index] = mergeDeliveryOrderRow(
      awaitingPreparationMealDeliveryOrders[index],
      row,
    );
  }

  /**
   * 派单成功后本地立刻改这一条，不等服务端推送
   *
   * 只构造一行最小的数据交给 [applyRealtimeUpdate]，让本地乐观更新和
   * Realtime 推送共用同一条代码路径——否则两条路径各自改一次列表和角标，
   * 会出现「扣两次数」和「按下标赋值时列表已经变短」的崩溃。
   */
  void applyDispatched(String? id, String status) {
    if (id == null) {
      return;
    }
    applyRealtimeUpdate(<String, dynamic>{'id': id, 'status': status});
  }
}
