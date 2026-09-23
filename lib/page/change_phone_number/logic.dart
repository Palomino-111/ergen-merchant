import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../common/getx/controller/account_controller.dart';
import '../../common/utility/common.dart';
import '../../common/utility/toast.dart';
import 'state.dart';

class ChangePhoneNumberLogic extends GetxController {
  final ChangePhoneNumberState state = ChangePhoneNumberState();

  @override
  void onInit() {
    super.onInit();
  }

  onNewPhoneNumberChanged(String phoneNumber) {
    state.newPhoneNumber = phoneNumber;
  }

  void getSMSVerificationCode(BuildContext context) async {
    // 防止重复发送，倒计时校验
    if (!state.isCounting.isTrue) {
      return;
    }

    // 校验手机号
    if (!isValidPhoneNumber(state.newPhoneNumber)) {
      showTextToast(context, "手机号不正确");
      return;
    }

    // 网络请求，获取验证码
    showPleaseWaitLoading(context);
    bool isSuccess = await AccountController.to.changePhone(
      state.newPhoneNumber,
    );
    closeAllLoading();
    if (!isSuccess) {
      showTextToast(context, "获取验证码失败");
      return;
    }

    // 获取验证码成功，启动定时器
    showTextToast(context, "获取验证码成功");
    state.isCounting.value = false;
    startTimer();
  }

  // 启动倒计时的计时器。
  void startTimer() {
    updateCountdown(ChangePhoneNumberState.interval);
    state.timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        if (state.countdown == 0) {
          state.timer?.cancel();
          state.countdown = ChangePhoneNumberState.interval;
          state.textOfGetSMSVerificationCodeButton.value = '重新发送';
          state.isCounting.value = true;
          return;
        }
        state.countdown--;
        updateCountdown(state.countdown);
        state.isCounting.value = false;
      },
    );
  }

  void updateCountdown(int countdown) {
    state.textOfGetSMSVerificationCodeButton.value = '$countdown秒后重试';
  }

  onSMSVerificationCodeChanged(String smsVerificationCode) {
    state.smsVerificationCode = smsVerificationCode;
  }

  void changePhoneNumber(BuildContext context) async {
    if (!isValidPhoneNumber(state.newPhoneNumber)) {
      showTextToast(context, "新手机号不正确");
      return;
    }
    if (!isValidSmsVerificationCode(state.smsVerificationCode)) {
      showTextToast(context, "验证码不合法");
      return;
    }
    // 网络请求，更换手机号
    showPleaseWaitLoading(context);
    bool isSuccess = await AccountController.to.verifyOTPOfChangePhone(
      state.newPhoneNumber,
      state.smsVerificationCode,
    );
    closeAllLoading();
    if (!isSuccess) {
      showTextToast(context, "修改失败");
      return;
    }
    showTextToast(context, "修改成功");
    Get.back();
  }
}
