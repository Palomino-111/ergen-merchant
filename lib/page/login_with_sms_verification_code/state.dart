import 'dart:async';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

class LoginWithSMSVerificationCodeState {
  String phoneNumber = "";

  String smsVerificationCode = "";

  // 两次验证发送之间的间隔时间
  static const int interval = 20;
  int countdown = interval;
  RxBool isCounting = true.obs;
  Timer? timer = null;
  RxString textOfGetSMSVerificationCodeButton = '获取验证码'.obs;

  RxBool hasAgreedToAgreements = false.obs;

  LoginWithSMSVerificationCodeState() {}
}
