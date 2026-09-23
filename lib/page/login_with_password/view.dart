import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../common/dimensions.dart';
import '../../../common/utility/common.dart';
import '../../../common/widget/app_bar_scaffold.dart';
import '../../../common/widget/bottom_bar_scaffold.dart';
import '../../../common/widget/page_scaffold.dart';
import '../web_view/view.dart';
import 'logic.dart';

class LoginWithPasswordPage extends StatelessWidget {
  LoginWithPasswordPage({Key? key}) : super(key: key);

  final logic = Get.put(LoginWithPasswordLogic());
  final state = Get.find<LoginWithPasswordLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginWithPasswordLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "密码登录",
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
                  child: Container(
                    child: Column(
                      children: [
                        // 手机号
                        buildPhoneNumberTitle(),
                        buildPhoneNumber(context),
                        // 密码
                        buildPasswordTitle(),
                        buildPassword(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: buildBottomBar(context),
        );
      },
    );
  }

  Widget buildPhoneNumberTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "手机号",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildPhoneNumber(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      height: Dimensions.button60,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: Dimensions.button60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: "请输入手机号",
                  contentPadding: EdgeInsets.all(Dimensions.padding16),
                ),
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
                onChanged: (s) => logic.onPhoneNumberChanged(s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPasswordTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "密码",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildPassword(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      height: Dimensions.button60,
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: Container(
                height: Dimensions.button60,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(Dimensions.borderRadius12),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: state.obscurePassword.value,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: "请输入密码",
                    contentPadding: EdgeInsets.all(Dimensions.padding16),
                  ),
                  style: TextStyle(
                    fontSize: Dimensions.fontSize24,
                  ),
                  onChanged: (s) => logic.onPasswordChanged(s),
                ),
              ),
            ),
            SizedBox(width: Dimensions.margin16),
            Container(
              height: Dimensions.button60,
              width: Dimensions.button60,
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: Dimensions.padding16),
                onPressed: () async {
                  logic.invertObscurePassword();
                },
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                child: Icon(
                  size: Dimensions.iconSize32,
                  state.obscurePassword.value
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: Container(
        margin: EdgeInsets.all(
          Dimensions.margin16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 协议勾选框
              buildAgreementsCheckbox(context),
              // 登录按钮
              buildLoginButton(context),
              // 忘记密码
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAgreementsCheckbox(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Obx(() {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
              child: BackdropFilter(
                filter: buildImageFilter(),
                child: CupertinoButton(
                  minSize: Dimensions.button60,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  padding: EdgeInsets.zero,
                  child: Transform.scale(
                    scale: 1.3,
                    child: Checkbox(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Dimensions.borderRadius4,
                        ),
                      ),
                      checkColor: Theme.of(context).colorScheme.onSurface,
                      activeColor: Colors.transparent,
                      fillColor: WidgetStateProperty.all(Colors.transparent),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      overlayColor:
                          WidgetStateProperty.all<Color?>(Colors.transparent),
                      value: state.hasAgreedToAgreements.value,
                      onChanged: (bool? value) {
                        state.hasAgreedToAgreements.value = value!;
                      },
                    ),
                  ),
                  onPressed: () async {},
                ),
              ),
            );
          }),
          SizedBox(
            width: Dimensions.padding16,
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: Dimensions.fontSize24,
                ),
                children: [
                  TextSpan(text: '我已阅读并同意'),
                  TextSpan(
                    text: '《用户协议》',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        Get.to(
                          WebViewPage(),
                          arguments: {
                            "uri": Uri.dataFromString(
                              await rootBundle.loadString(
                                "assets/用户协议.html",
                              ),
                              mimeType: 'text/html',
                              encoding: Encoding.getByName('utf-8'),
                            ),
                            "title": "用户协议",
                          },
                        );
                      },
                  ),
                  TextSpan(
                    text: '和',
                  ),
                  TextSpan(
                    text: '《隐私政策》',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        Get.to(
                          WebViewPage(),
                          arguments: {
                            "uri": Uri.dataFromString(
                              await rootBundle.loadString(
                                "assets/隐私政策.html",
                              ),
                              mimeType: 'text/html',
                              encoding: Encoding.getByName('utf-8'),
                            ),
                            "title": "隐私政策",
                          },
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLoginButton(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      width: double.infinity,
      margin: EdgeInsets.only(top: Dimensions.margin16),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Text(
          "登录",
          style: TextStyle(
            fontSize: Dimensions.fontSize32,
          ),
        ),
        onPressed: () async {
          logic.login(context);
        },
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
