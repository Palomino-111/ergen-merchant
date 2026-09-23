import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/page/main/view.dart';
import '../../common/getx/controller/account_controller.dart';
import '../../common/utility/common.dart';
import '../../common/utility/toast.dart';
import 'state.dart';

class LoginWithSMSVerificationCodeLogic extends GetxController {
  final LoginWithSMSVerificationCodeState state =
      LoginWithSMSVerificationCodeState();

  @override
  void onInit() {
    super.onInit();
  }

  onPhoneNumberChanged(String phoneNumber) {
    state.phoneNumber = phoneNumber;
  }

  void getSMSVerificationCode(BuildContext context) async {
    // 防止重复发送，倒计时校验
    if (!state.isCounting.isTrue) {
      return;
    }
    // 校验手机号
    if (!isValidPhoneNumber(state.phoneNumber)) {
      showTextToast(context, "手机号不正确");
      return;
    }
    // 网络请求，获取验证码
    showPleaseWaitLoading(context);
    final isSuccess = await AccountController.to
        .loginWithSMSVerificationCode(state.phoneNumber);
    closeAllLoading();
    if (!isSuccess) {
      // 把真实原因（超时/服务端报错）告诉用户，别只弹一句「发送失败」
      showTextToast(
        context,
        AccountController.to.lastErrorMessage ?? '发送失败',
      );
      return;
    }
    // 发送验证码成功，启动定时器
    showTextToast(context, '发送成功');
    state.isCounting.value = false;
    startTimer();
    refresh();
  }

  // 启动倒计时的计时器。
  void startTimer() {
    updateCountdown(LoginWithSMSVerificationCodeState.interval);
    state.timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        if (state.countdown == 0) {
          state.timer?.cancel();
          state.countdown = LoginWithSMSVerificationCodeState.interval;
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

  /**
   * 使用supabase进行注册于登录
   */
  void login(BuildContext context) async {
    if (!isValidPhoneNumber(state.phoneNumber)) {
      showTextToast(context, "手机号不正确");
      return;
    }
    if (!isValidSmsVerificationCode(state.smsVerificationCode)) {
      showTextToast(context, "验证码不合法");
      return;
    }
    if (!state.hasAgreedToAgreements.isTrue) {
      showTextToast(context, "请阅读并同意\n《用户协议》、《隐私政策》");
      return;
    }
    showPleaseWaitLoading(context);
    bool isSuccess = await AccountController.to.verifyOTP(
      state.phoneNumber,
      state.smsVerificationCode,
    );
    closeAllLoading();
    if (!isSuccess) {
      // 把真实原因（超时/服务端报错）告诉用户，别只弹一句「登录失败」
      showTextToast(
        context,
        AccountController.to.lastErrorMessage ?? '登录失败',
      );
      return;
    }
    Get.offAll(MainPage());
    showTextToast(context, "登陆成功");
  }
}
