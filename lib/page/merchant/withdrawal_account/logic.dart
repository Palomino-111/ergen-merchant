import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'state.dart';

class WithdrawalAccountLogic extends GetxController {
  final WithdrawalAccountState state = WithdrawalAccountState();

  @override
  Future<void> onInit() async {
    super.onInit();
    await MerchantController.to.fetchWithdrawalAccountList();
  }
}
