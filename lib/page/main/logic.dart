import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/models/delivery_status.dart';
import 'state.dart';

class MainLogic extends GetxController with GetTickerProviderStateMixin {
  late TabController mainTabController;
  late TabController planTabController;

  final MainState state = MainState();

  @override
  void onInit() {
    super.onInit();
    mainTabController = TabController(length: 2, vsync: this);
    // 分组 tab 的数量直接取自 DeliveryStatusGroup，不要在两边各写一个数字：
    // 减/加分组时这里漏改的表现是「多出来的 tab 点不动」或直接抛异常
    planTabController = TabController(
      length: DeliveryStatusGroup.values.length,
      vsync: this,
    );
  }

  @override
  void onClose() {
    mainTabController.dispose();
    planTabController.dispose();
    super.onClose();
  }

    /// 跳到「生产计划」页的「待制作」tab。
  ///
  /// 两个 TabController 都是这里持有的，所以在同一个类里做跳转最自然
  /// （散在各个页面里 animateTo(0) 早晚会有人漏改 index 顺序）。
  ///
  /// 调用方：
  ///   - TpnsService.onOrderClicked 注入的回调（见 main.dart）
  ///   - 冷启动消费 pending orderId（见 MainPage）
  ///
  /// **只切 tab，不做滚动/高亮**：列表是分页的，为了高亮一单去翻页会把
  /// 商家当前浏览位置搞乱（见 realtime_controller 那段「刻意不插入」的注释）。
  /// 当前 MVP 先切到正确的 tab，滚动/高亮留到后面真正有需要时再做。
  void jumpToPendingOrder(String orderId) {
    if (mainTabController.index != 0) {
      mainTabController.animateTo(0);
    }
    if (planTabController.index != 0) {
      planTabController.animateTo(0);
    }
    // 订单 id 目前只用于日志，将来做滚动高亮时会用到
    print('🔵 [MainLogic] 跳到待制作 tab, orderId=$orderId');
  }
}
