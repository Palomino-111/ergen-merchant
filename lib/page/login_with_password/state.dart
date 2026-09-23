import 'package:get/get_rx/src/rx_types/rx_types.dart';

class LoginWithPasswordState {
  String phoneNumber = "";
  String password = "";
  RxBool obscurePassword = false.obs;
  RxBool hasAgreedToAgreements = false.obs;

  LoginWithPasswordState() {}
}
