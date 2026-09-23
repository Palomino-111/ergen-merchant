import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'state.dart';

class MerchantLogic extends GetxController {
  final MerchantState state = MerchantState();

  @override
  Future<void> onInit() async {
    super.onInit();
    MerchantController.to.fetchFundsInformation();
  }
}
