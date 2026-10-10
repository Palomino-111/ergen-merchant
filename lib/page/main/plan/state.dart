import 'package:easy_refresh/easy_refresh.dart';

import '../../../common/models/delivery_status.dart';

class PlanState {
  /// 每个分组（tab）一个刷新控制器，按分组取。
  ///
  /// 用 Map 而不是三个独立字段：以后加/减分组时这里不用改，
  /// 也不会出现「新加了一个 tab 但忘了给它建 EasyRefreshController」。
  final Map<DeliveryStatusGroup, EasyRefreshController> easyRefreshControllers = {
    for (final DeliveryStatusGroup group in DeliveryStatusGroup.values)
      group: EasyRefreshController(
        controlFinishRefresh: false,
        controlFinishLoad: false,
      ),
  };

  PlanState() {}
}
