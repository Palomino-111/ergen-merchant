import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../../../common/getx/controller/merchant_controller.dart';

class AddWithdrawalAccountState {
  final merchant = MerchantController.to.merchant;

  String bankName = '';
  final bankNameController = TextEditingController();
  String bankAccountNumber = '';
  String bankAccountHolder = '';
  RxBool isDefault = RxBool(true);

  AddWithdrawalAccountState() {}
}
