import 'package:get/get_rx/src/rx_types/rx_types.dart';

class ChangePasswordState {
  String password = "";
  RxBool obscurePassword = false.obs;

  ChangePasswordState() {}
}
