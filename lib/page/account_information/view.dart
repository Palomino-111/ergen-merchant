import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/utility/toast.dart';
import 'package:zheergen_merchant_end/page/main/view.dart';
import '../../common/dimensions.dart';
import '../../common/getx/controller/account_controller.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../../common/widget/dialog/text_dialog.dart';
import '../../common/widget/page_scaffold.dart';
import '../change_password/view.dart';
import '../change_phone_number/view.dart';
import 'logic.dart';

class AccountInformationPage extends StatelessWidget {
  AccountInformationPage({Key? key}) : super(key: key);

  final logic = Get.put(AccountInformationLogic());
  final state = Get.find<AccountInformationLogic>().state;
  final user = AccountController.to.user;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AccountInformationLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "账号",
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: Dimensions.margin16,
                    // 状态栏占位 + AppBar占位
                    top: MediaQuery.of(context).padding.top +
                        AppBarScaffold.appBarHeight -
                        Dimensions.margin16,
                    right: Dimensions.margin16,
                    bottom: Dimensions.margin16 * 2 +
                        Dimensions.button60 +
                        Dimensions.margin16 * 2,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // 账号信息
                      buildAccountInformation(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAccountInformation(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: Dimensions.margin16),
            alignment: Alignment.centerLeft,
            child: Text(
              "折耳根账号",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            child: Container(
              child: Column(
                children: [
                  // 手机号
                  buildPhoneNumber(context),
                  // 修改密码
                  buildChangePassword(context),
                  // 退出登录
                  buildLogout(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPhoneNumber(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.only(
          left: Dimensions.padding16,
          right: Dimensions.padding16,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "手机号码",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            Obx(
              () => Text(
                "${user.value?.phone}",
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            SizedBox(width: Dimensions.padding8),
            Icon(
              size: Dimensions.iconSize32,
              Icons.arrow_forward,
            ),
          ],
        ),
        onPressed: () async {
          Get.to(ChangePhoneNumberPage());
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Widget buildChangePassword(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.only(
          left: Dimensions.padding16,
          right: Dimensions.padding16,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "修改密码",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            SizedBox(width: Dimensions.padding8),
            Icon(
              size: Dimensions.iconSize32,
              Icons.arrow_forward,
            ),
          ],
        ),
        onPressed: () async {
          Get.to(ChangePasswordPage());
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Widget buildLogout(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.only(
          left: Dimensions.padding16,
          right: Dimensions.padding16,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "退出登录",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            SizedBox(width: Dimensions.padding8),
            Icon(
              size: Dimensions.iconSize32,
              Icons.logout,
            ),
          ],
        ),
        onPressed: () async {
          showLogoutAlertDialog(context);
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Future<void> showLogoutAlertDialog(BuildContext context) async {
    showDialog<String>(
      context: context,
      builder: (context) => TextDialog(
        title: "确认退出登录？",
        actions: [
          CupertinoButton(
            minSize: Dimensions.button60,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            child: Text(
              "确认",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
            onPressed: () => Navigator.pop(context, 'confirm'),
          ),
          SizedBox(height: Dimensions.margin16),
          CupertinoButton(
            minSize: Dimensions.button60,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            child: Text(
              "取消",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
            onPressed: () => Navigator.pop(context, 'cancel'),
          ),
        ],
      ),
    ).then((value) async {
      if (value == 'confirm') {
        showPleaseWaitLoading(context);
        await AccountController.to.logout();
        closeAllLoading();
        Get.offAll(MainPage());
      }
    });
  }
}
