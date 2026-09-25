import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/data/repository/meal_repository.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/awaiting_preparation_meal_delivery_order_controller.dart';
import '../../../common/exception/showable_exception.dart';
import '../../../common/getx/controller/meal_delivery_order_controller/all_meal_delivery_order_controller.dart';
import '../../../common/getx/controller/meal_delivery_order_controller/utility.dart';
import '../../../common/models/dispatch_result.dart';
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

  /**
   * 派单（呼叫骑手）
   *
   * [mealDeliveryOrder] 要派单的配送订单
   *
   * 返回值：成功返回 DispatchResult，失败返回 null
   * （失败的提示文案已经在方法内部 toast 过了，调用方只需判断 null）
   *
   * ⚠️ 这个接口会产生真实费用，任何情况下都不要在这里自动重试
   */
  Future<DispatchResult?> dispatchMealDeliveryOrder(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
  ) async {
    final orderId = mealDeliveryOrder.id;
    if (orderId == null || orderId.isEmpty) {
      showTextToast(context, "😂 配送订单ID为空，无法派单！");
      return null;
    }

    try {
      showPleaseWaitLoading(context);
      // 成功不在这一层 toast：要区分「首次派单」和「幂等返回」两种文案，
      // 由 view 层根据 result.alreadyDispatched 决定
      final result = await dispatchDeliveryOrderByRemote(orderId);
      closeAllLoading();
      return result;
    } on ShowableException catch (e) {
      showTextToast(context, e.message);
    } catch (e, st) {
      print("dispatchMealDeliveryOrder, $e, $st");
      showTextToast(context, "😂 派单失败，未知错误！");
    }
    closeAllLoading();
    return null;
  }
}
