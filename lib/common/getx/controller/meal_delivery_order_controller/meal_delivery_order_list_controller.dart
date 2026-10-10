import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';

import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../env.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/delivery_status.dart';
import '../../../models/meal_delivery_order.dart';
import 'realtime_utility.dart';

/// 一个分组（= 一个 tab）的配送单列表。
///
/// 「订单」页的三个分组共用这一份实现：分组之间只差
/// [group]（status 集合 + 排序方向 + 要不要角标），
/// 所以分页、刷新、按 id 局部更新这些逻辑**只有一份**。
///
/// 为什么不在 view 里复制三遍：这份逻辑里有几处很容易写错的东西——
/// 角标的幂等扣减、Realtime 到来时列表已经变短的越界风险、
/// 局部更新的合并规则（不能冲掉 meal/dish_sku 嵌套）。
/// 复制三份意味着三倍的同款 bug。
class MealDeliveryOrderListController extends GetxController {
  MealDeliveryOrderListController({required this.group});

  /// 本列表对应的分组。分组定义见 [DeliveryStatusGroup]，
  /// 是 status 集合、排序方向、角标、文案的唯一事实来源。
  final DeliveryStatusGroup group;

  /// 本组的配送单列表
  final RxList<MealDeliveryOrder> orders = RxList();

  /// 服务端总数。
  ///
  /// 只有 [DeliveryStatusGroup.countBadge] 为 true 的分组才会去查，
  /// 其余分组这个值恒为 0（不要拿它当"本页条数"用，那是 [orders.length]）。
  final RxInt count = 0.obs;

  final MealDeliveryOrderRepository _repository = Get.find();

  // 每页数据量
  int pageSize = 20;

  // 当前页码（从 0 开始）
  int currentPage = 0;

  // 是否有更多数据
  bool hasMore = true;

  /// 获取本组的餐配送列表
  /// [isRefresh]，是否是刷新，true表示刷新，清空列表，重新从第一页数据获取，false表示加载下一页数据
  Future<void> fetchMealDeliveryOrders({
    // 是否是刷新 下拉刷新相当于获取第一页数据
    bool isRefresh = false,
  }) async {
    try {
      // 正常取登录用户对应的店铺；未登录时可用 DEBUG_MERCHANT_ID 兜底（仅调试）
      final merchantId =
          MerchantController.to.merchant.value?.id ?? Env.debugMerchantId;
      if (merchantId == null) throw ShowableException('商家未登录！');

      final int newPage = isRefresh ? 0 : currentPage + 1;

      // 只算一次：列表和角标必须用同一个下界，
      // 否则恰好在午夜前刷新会查出两个不同的「今天」
      final DateTime? deliveryTimeFrom = group.deliveryTimeFrom;

      // 门店归属过滤（merchant_id）+ 分组的状态集合过滤都写在数据层，
      // 并一次把 meal / meal_dish / dish_sku 嵌套查回来，item 不用再逐个查餐品。
      // 排序方向也由分组决定：未结束的组按送达时间升序，商家才看得到
      // 「接下来该做哪一单」；同时带上「今天 00:00」这道下界，
      // 否则升序会把一年前那些没派单的僵尸单排到最前面。
      final List<MealDeliveryOrder> result =
          await _repository.fetchByMerchant(
        merchantId: merchantId,
        statuses: group.statuses,
        ascending: group.ascending,
        deliveryTimeFrom: deliveryTimeFrom,
        page: newPage,
        pageSize: pageSize,
      );

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        orders.assignAll(result);
      } else {
        orders.addAll(result);
      }

      // 总数只在刷新（或首次加载）时取一次：上拉加载更多不会改变总数，省一个请求。
      // 过滤条件必须和上面列表完全一致，否则角标会和列表条数对不上。
      if (group.countBadge && (isRefresh || count.value == 0)) {
        count.value = await _repository.countByMerchant(
          merchantId: merchantId,
          statuses: group.statuses,
          deliveryTimeFrom: deliveryTimeFrom,
        );
      }

      this.currentPage = newPage;
    } on ShowableException {
      rethrow;
    } catch (e) {
      print("fetchMealDeliveryOrders, group=${group.name}, fail, $e");
      throw ShowableException('获取订单失败，未知错误！');
    }
  }

  /// 主动拉一次本组总数（角标）
  Future<int> getCountFromRemote() async {
    try {
      // 正常取登录用户对应的店铺；未登录时可用 DEBUG_MERCHANT_ID 兜底（仅调试）
      final merchantId =
          MerchantController.to.merchant.value?.id ?? Env.debugMerchantId;
      if (merchantId == null) throw ShowableException('商家未登录！');

      final int total = await _repository.countByMerchant(
        merchantId: merchantId,
        statuses: group.statuses,
        deliveryTimeFrom: group.deliveryTimeFrom,
      );
      count.value = total;
      return total;
    } on ShowableException {
      rethrow;
    } catch (e) {
      print("getCountFromRemote, group=${group.name}, fail, $e");
      throw ShowableException('获取订单数失败，未知错误！');
    }
  }

  /// 用一条数据库行更新本列表里对应的那一单
  ///
  /// 数据来源有三条，最终都走这里，所以「同一个状态变化」只会生效一次：
  /// - Realtime 推送的 newRecord
  /// - 回到前台时按 id 批量重查的结果
  /// - 派单成功后本地的乐观更新（走 [applyDispatched]）
  ///
  /// 规则：这个列表只该有本分组状态集合里的单，
  /// 状态一旦离开本分组就**立刻移除**并同步角标，不用等商家下拉刷新。
  ///
  /// 幂等性靠「移除之后就再也找不到这一条」实现：晚到的那条路径会因为
  /// indexWhere 返回 -1 直接退出，所以角标不会被重复扣减。
  ///
  /// **刻意不做的事：不插入。** 订阅收到的是全店变更，一条单从别的分组
  /// 变成属于本分组（例如商家在「待制作」派单，单子进入「在途」）时，
  /// 这里什么也不做——因为插入位置涉及分页顺序，插错了会把列表顺序搞乱、
  /// 甚至和已翻页的数据重复。这类「新进入本分组的单」要靠下拉刷新带出来。
  /// 要做到自动出现，得改成「各 tab 共享一份内存数据 + 视图过滤」，那是另一件事。
  void applyRealtimeUpdate(Map<String, dynamic> row) {
    final String? id = row['id'] as String?;
    if (id == null) {
      return;
    }
    final int index = orders.indexWhere(
      (order) => order.id == id,
    );
    // 不在本列表里（没加载到 / 已经被移除 / 属于别的分组）就什么都不做
    if (index < 0) {
      return;
    }

    final String? newStatus = row['status'] as String?;
    if (newStatus != null && !group.containsStatus(newStatus)) {
      orders.removeAt(index);
      // 本地这份还是本分组的状态，说明这次移除是账号上第一次看到的状态变化，
      // 服务端的本组总数也确实少了一个，角标跟着减
      if (group.countBadge && count.value > 0) {
        count.value -= 1;
      }
      return;
    }

    orders[index] = mergeDeliveryOrderRow(
      orders[index],
      row,
    );
  }

  /// 派单成功后本地立刻改这一条，不等服务端推送
  ///
  /// 只构造一行最小的数据交给 [applyRealtimeUpdate]，让本地乐观更新和
  /// Realtime 推送共用同一条代码路径——否则两条路径各自改一次列表和角标，
  /// 会出现「扣两次数」和「按下标赋值时列表已经变短」的崩溃。
  void applyDispatched(String? id, String status) {
    if (id == null) {
      return;
    }
    applyRealtimeUpdate(<String, dynamic>{'id': id, 'status': status});
  }
}

/// 待制作：要商家出餐 → 派单
class ToPrepareMealDeliveryOrderController
    extends MealDeliveryOrderListController {
  ToPrepareMealDeliveryOrderController()
      : super(group: DeliveryStatusGroup.toPrepare);

  static ToPrepareMealDeliveryOrderController get to => Get.find();
}

/// 在途：已派单，等骑手取餐 / 骑手在路上
class InTransitMealDeliveryOrderController
    extends MealDeliveryOrderListController {
  InTransitMealDeliveryOrderController()
      : super(group: DeliveryStatusGroup.inTransit);

  static InTransitMealDeliveryOrderController get to => Get.find();
}

/// 已结束：已送达 / 已收货 / 已取消
class FinishedMealDeliveryOrderController
    extends MealDeliveryOrderListController {
  FinishedMealDeliveryOrderController()
      : super(group: DeliveryStatusGroup.finished);

  static FinishedMealDeliveryOrderController get to => Get.find();
}

/// 全部：不过滤状态，查单/兜底入口
class AllMealDeliveryOrderController extends MealDeliveryOrderListController {
  AllMealDeliveryOrderController() : super(group: DeliveryStatusGroup.all);

  static AllMealDeliveryOrderController get to => Get.find();
}

/// 「订单」页的全部分组列表控制器，**顺序即 tab 顺序**。
///
/// view 按它生成 tab；Realtime 分发/回前台补数据也按它遍历，
/// 这样新加一个分组时只有这里要改，不会出现「某个列表收不到推送」。
///
/// 前置条件：这些控制器都已 `Get.put`（见 main.dart 的 initGetX）。
List<MealDeliveryOrderListController> mealDeliveryOrderListControllers() {
  return <MealDeliveryOrderListController>[
    ToPrepareMealDeliveryOrderController.to,
    InTransitMealDeliveryOrderController.to,
    FinishedMealDeliveryOrderController.to,
    AllMealDeliveryOrderController.to,
  ];
}
