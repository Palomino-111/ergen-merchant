import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/data/repository/meal_repository.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/awaiting_preparation_meal_delivery_order_controller.dart';
import '../../../common/exception/showable_exception.dart';
import '../../../common/getx/controller/meal_delivery_order_controller/all_meal_delivery_order_controller.dart';
import '../../../common/getx/controller/meal_delivery_order_controller/utility.dart';
import '../../../common/models/meal_delivery_order.dart';
import '../../../common/utility/toast.dart';
import 'state.dart';

class PlanLogic extends GetxController {
  final awaitingPreparationMealDeliveryOrderController =
      AwaitingPreparationMealDeliveryOrderController.to;
  final allMealDeliveryOrderController = AllMealDeliveryOrderController.to;
  final MealRepository mealRepository = Get.find();

  final PlanState state = PlanState();

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() async {
    super.onReady();
    // if (awaitingPreparationMealDeliveryOrderController
    //     .awaitingPreparationMealDeliveryOrders.isEmpty) {
    //   await state.awaitingPreparationEasyRefreshController.callRefresh(
    //     overOffset: 150,
    //     duration: Duration(milliseconds: 300),
    //   );
    // }
    // if (allMealDeliveryOrderController.allMealDeliveryOrders.isEmpty) {
    //   await state.allEasyRefreshController.callRefresh(
    //     overOffset: 150,
    //     duration: Duration(milliseconds: 300),
    //   );
    // }
  }

  /**
   * 更新配送订单信息
   * [newMealDeliveryOrder] 新的配送订单对象
   * 返回值 bool 为 true 表示更新成功，反之为失败
   */
  Future<bool> updateMealDeliveryOrder(
    BuildContext context,
    MealDeliveryOrder newMealDeliveryOrder,
  ) async {
    try {
      showPleaseWaitLoading(context);
      await updateMealDeliveryOrderByRemote(
        newMealDeliveryOrder,
      );
      closeAllLoading();
      showTextToast(context, "🥳 开始配送");
      return true;
    } on ShowableException catch (e) {
      showTextToast(context, e.message);
    } catch (e, st) {
      print("updateMealDeliveryOrder, $e, $st");
      showTextToast(context, "😂 状态更改失败，未知错误！");
    }
    closeAllLoading();
    return false;
  }
}
