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
}
