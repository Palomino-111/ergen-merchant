import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/page/merchant/view.dart';
import '../../../common/dimensions.dart';
import '../../../common/getx/controller/account_controller.dart';
import '../../../common/widget/page_scaffold.dart';
import '../../about_zheergen/view.dart';
import '../../account_information/view.dart';
import '../../login_with_sms_verification_code/view.dart';
import '../../web_view/view.dart';
import 'logic.dart';

class MyPage extends StatelessWidget {
  MyPage({Key? key}) : super(key: key);

  final logic = Get.put(MyLogic());
  final state = Get.find<MyLogic>().state;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                // 状态栏占位
                top: MediaQuery.of(context).padding.top,
                bottom: Dimensions.margin16 * 2 +
                    Dimensions.button60 +
                    Dimensions.margin16 * 2,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 店铺
                  buildMerchant(context),
                  // 账号
                  buildAccount(context),
                  // 其它
                  buildOthers(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOthers(BuildContext context) {
    return Column(
      children: [
        // 其它
        Container(
          margin: EdgeInsets.only(
            left: Dimensions.margin16,
            top: Dimensions.margin16,
            right: Dimensions.margin16,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            "其它",
            style: TextStyle(
              fontSize: Dimensions.fontSize32,
            ),
          ),
        ),
        // 意见反馈
        Container(
          margin: EdgeInsets.only(
            left: Dimensions.margin16,
            top: Dimensions.margin16,
            right: Dimensions.margin16,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.all(Dimensions.padding16),
            borderRadius: BorderRadius.all(
              Radius.circular(Dimensions.borderRadius12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "意见反馈",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: Dimensions.iconSize32,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
            onPressed: () async {
              Get.to(
                WebViewPage(),
                arguments: {
                  "uri": Uri.parse(
                    "https://sfmvkco5qd.feishu.cn/share/base/form/shrcndpolbtT45ZUeNd8ZD1nEQW",
                  ),
                  "title": "意见反馈"
                },
              );
            },
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        // 关于我们
        Container(
          margin: EdgeInsets.only(
            left: Dimensions.margin16,
            top: Dimensions.margin16,
            right: Dimensions.margin16,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.all(Dimensions.padding16),
            borderRadius: BorderRadius.all(
              Radius.circular(Dimensions.borderRadius12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "关于我们",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: Dimensions.iconSize32,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
            onPressed: () async {
              Get.to(AboutZheergenPage());
            },
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget buildMerchantInformation(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: Dimensions.margin16,
        top: Dimensions.margin16,
        right: Dimensions.margin16,
      ),
      child: CupertinoButton(
        minSize: Dimensions.button60,
        padding: EdgeInsets.all(Dimensions.padding16),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Column(
          children: [
            // 账号
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${MerchantController.to.merchant.value?.name}",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
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
          ],
        ),
        onPressed: () async {
          Get.to(MerchantPage());
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Widget buildMerchant(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: Dimensions.margin16,
            top: Dimensions.margin16,
            right: Dimensions.margin16,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            "店铺",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: Dimensions.fontSize32,
            ),
          ),
        ),
        // 登录 & 账号信息
        Obx(
          () => AccountController.to.session.value?.isExpired == false
              ? buildMerchantInformation(context)
              : buildLogin(context),
        ),
      ],
    );
  }

  Widget buildAccount(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: Dimensions.margin16,
            top: Dimensions.margin16,
            right: Dimensions.margin16,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            "账号",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: Dimensions.fontSize32,
            ),
          ),
        ),
        // 登录 & 账号信息
        Obx(
          () => AccountController.to.session.value?.isExpired == false
              ? buildAccountInformation(context)
              : buildLogin(context),
        ),
      ],
    );
  }

  Widget buildLogin(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: Dimensions.margin16,
        top: Dimensions.margin16,
        right: Dimensions.margin16,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.all(Dimensions.padding16),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "立即登录",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize32,
                ),
              ),
            ),
            SizedBox(width: Dimensions.padding8),
            Icon(
              size: Dimensions.iconSize32,
              Icons.login,
            ),
          ],
        ),
        onPressed: () async {
          Get.to(LoginWithSMSVerificationCodePage());
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  Widget buildAccountInformation(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: Dimensions.margin16,
        top: Dimensions.margin16,
        right: Dimensions.margin16,
      ),
      child: CupertinoButton(
        minSize: Dimensions.button60,
        padding: EdgeInsets.all(Dimensions.padding16),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Column(
          children: [
            // 账号
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${AccountController.to.user.value?.phone}",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
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
          ],
        ),
        onPressed: () async {
          Get.to(AccountInformationPage());
        },
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }
}
