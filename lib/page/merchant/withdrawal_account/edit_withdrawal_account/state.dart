import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import '../../../../common/getx/controller/merchant_controller.dart';

class EditWithdrawalAccountState {
  final merchant = MerchantController.to.merchant;

  final WithdrawalAccount withdrawalAccount;
  final bankNameController = TextEditingController();
  final bankAccountNumberController = TextEditingController();
  final bankAccountHolderController = TextEditingController();
  RxBool isDefault = RxBool(true);

  EditWithdrawalAccountState(this.withdrawalAccount) {
    bankNameController.text = withdrawalAccount.bankName;
    bankAccountNumberController.text = withdrawalAccount.bankAccountNumber;
    bankAccountHolderController.text = withdrawalAccount.bankAccountHolder;
    isDefault.value = withdrawalAccount.isDefault;
  }
}
