import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/page/main/view.dart';
import '../../../common/getx/controller/account_controller.dart';
import '../../../common/utility/common.dart';
import '../../../common/utility/toast.dart';
import 'state.dart';

class LoginWithPasswordLogic extends GetxController {
  final LoginWithPasswordState state = LoginWithPasswordState();

  @override
  void onInit() {
    super.onInit();
  }

  onPhoneNumberChanged(String phoneNumber) {
    state.phoneNumber = phoneNumber;
  }

  onPasswordChanged(String password) {
    state.password = password;
  }

  void login(BuildContext context) async {
    if (!isValidPhoneNumber(state.phoneNumber)) {
      showTextToast(context, "手机号不正确");
      return;
    }
    if (!isValidPassword(state.password)) {
      showTextToast(context, "密码不合法");
      return;
    }
    if (!state.hasAgreedToAgreements.isTrue) {
      showTextToast(context, "请阅读并同意\n《用户协议》、《隐私政策》");
      return;
    }
    // 网络请求，密码登录
    showPleaseWaitLoading(context);
    bool isSuccess = await AccountController.to.loginWithPassword(
      state.phoneNumber,
      state.password,
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
    showTextToast(context, '登录成功');
    Get.offAll(MainPage());
  }

  void invertObscurePassword() {
    state.obscurePassword.value = !state.obscurePassword.value;
  }
}
