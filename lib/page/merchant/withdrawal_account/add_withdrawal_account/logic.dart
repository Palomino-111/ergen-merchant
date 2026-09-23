import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import '../../../../common/exception/showable_exception.dart';
import '../../../../common/getx/controller/merchant_controller.dart';
import '../../../../common/utility/toast.dart';
import 'state.dart';

class AddWithdrawalAccountLogic extends GetxController {
  final AddWithdrawalAccountState state = AddWithdrawalAccountState();

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  Future<void> addWithdrawalAccount(BuildContext context) async {
    if (state.bankName == "" ||
        state.bankAccountNumber == "" ||
        state.bankAccountHolder == "") {
      showTextToast(context, '😝 还没填写完整哦！');
    }
    final merchantId = state.merchant.value!.id;
    if (merchantId == null) {
      showTextToast(context, '😂 未登录!');
      return;
    }
    // TODO 检查默认提现账号需要且只能有一个
    try {
      showPleaseWaitLoading(context);
      await MerchantController.to.addWithdrawalAccount(WithdrawalAccount(
        merchantId: merchantId,
        bankName: state.bankName,
        bankAccountNumber: state.bankAccountNumber,
        bankAccountHolder: state.bankAccountHolder,
        isDefault: state.isDefault.value,
      ));
      closeAllLoading();
      showTextToast(context, "🥳 添加成功");
      Get.back();
    } on ShowableException catch (e) {
      showTextToast(context, e.message);
    } catch (e, st) {
      print("addWithdrawalAccount, $e, $st");
      showTextToast(context, "😂 添加失败，未知错误！");
    }
    closeAllLoading();
  }
}
