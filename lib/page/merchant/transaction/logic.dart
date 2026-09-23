import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/transaction_controller.dart';
import 'state.dart';

class TransactionLogic extends GetxController {
  final TransactionState state = TransactionState();

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void onReady() async {
    super.onReady();
    if (TransactionController.to.transactions.isEmpty) {
      await state.easyRefreshController.callRefresh(
        overOffset: 150,
        duration: Duration(milliseconds: 300),
      );
    }
  }
}
