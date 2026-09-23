import 'package:get/get.dart';
import 'state.dart';

class MyLogic extends GetxController {
  final MyState state = MyState();

  @override
  void refresh() {
    super.refresh();
    print("页面刷新 refresh");
  }

  @override
  void onReady() {
    super.onReady();
    print("页面 onReady");
  }

  @override
  void onClose() {
    super.onClose();
    print("页面 onClose");
  }

  @override
  void onInit() {
    super.onInit();
    print("页面 onInit");
  }
}
