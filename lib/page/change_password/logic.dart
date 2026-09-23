import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../common/getx/controller/account_controller.dart';
import '../../common/utility/common.dart';
import '../../common/utility/toast.dart';
import 'state.dart';

class ChangePasswordLogic extends GetxController {
  final ChangePasswordState state = ChangePasswordState();

  @override
  void onInit() {
    super.onInit();
  }

  onPasswordChanged(String password) {
    state.password = password;
  }

  void invertObscurePassword() {
    state.obscurePassword.value = !state.obscurePassword.value;
  }

  void changePassword(BuildContext context) async {
    if (!isValidPassword(state.password)) {
      showTextToast(context, "密码不合法");
      return;
    }
    // 网络请求，修改密码
    showPleaseWaitLoading(context);
    bool isSuccess = await AccountController.to.changePassword(
      state.password,
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
