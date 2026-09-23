import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import '../../../../common/exception/showable_exception.dart';
import '../../../../common/getx/controller/merchant_controller.dart';
import '../../../../common/utility/toast.dart';
import 'state.dart';

class EditWithdrawalAccountLogic extends GetxController {
  final EditWithdrawalAccountState state;

  EditWithdrawalAccountLogic(
    WithdrawalAccount withdrawalAccount,
  ) : state = EditWithdrawalAccountState(withdrawalAccount);

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  Future<void> updateWithdrawalAccount(BuildContext context) async {
    String bankName = state.bankNameController.text;
    String bankAccountNumber = state.bankAccountNumberController.text;
    String bankAccountHolder = state.bankAccountHolderController.text;
    if (bankName == "" || bankAccountNumber == "" || bankAccountHolder == "") {
      showTextToast(context, '😝 还没填写完整哦！');
    }
    // TODO 检查默认提现账号需要且只能有一个
    try {
      showPleaseWaitLoading(context);
      await MerchantController.to.updateWithdrawalAccount(
        WithdrawalAccount(
          id: state.withdrawalAccount.id,
          merchantId: state.withdrawalAccount.merchantId,
          bankName: bankName,
          bankAccountNumber: bankAccountNumber,
          bankAccountHolder: bankAccountHolder,
          isDefault: state.isDefault.value,
        ),
      );
      closeAllLoading();
      showTextToast(context, "🥳 更新成功");
      Get.back();
    } on ShowableException catch (e) {
      showTextToast(context, e.message);
    } catch (e, st) {
      print("addWithdrawalAccount, $e, $st");
      showTextToast(context, "😂 添加失败，未知错误！");
    }
    closeAllLoading();
  }

  Future<void> deleteWithdrawalAccount(BuildContext context) async {
    try {
      showPleaseWaitLoading(context);
      await MerchantController.to.deleteWithdrawalAccount(
        state.withdrawalAccount,
      );
      closeAllLoading();
      showTextToast(context, "🥳 删除成功");
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
