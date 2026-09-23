import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../common/dimensions.dart';
import '../../common/getx/controller/account_controller.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../../common/widget/bottom_bar_scaffold.dart';
import '../../common/widget/page_scaffold.dart';
import 'logic.dart';

class ChangePhoneNumberPage extends StatelessWidget {
  ChangePhoneNumberPage({Key? key}) : super(key: key);

  final logic = Get.put(ChangePhoneNumberLogic());
  final state = Get.find<ChangePhoneNumberLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChangePhoneNumberLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "更换手机号码",
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
                        // 当前手机号
                        buildCurrentPhoneNumberTitle(),
                        buildCurrentPhoneNumber(context),
                        // 新手机号
                        buildNewPhoneNumberTitle(),
                        buildNewPhoneNumber(context),
                        // 验证码
                        buildSMSVerificationCodeTitle(),
                        buildSMSVerificationCode(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: buildBottomBar(context),
          // bottomWidget: Container(),
        );
      },
    );
  }

  Widget buildCurrentPhoneNumberTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "当前绑定的手机号",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildCurrentPhoneNumber(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      height: Dimensions.button60,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: Dimensions.button60,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.all(Dimensions.padding16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
              ),
              child: Text(
                "${AccountController.to.user.value?.phone}",
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNewPhoneNumberTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "输入要绑定的新手机号",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildNewPhoneNumber(BuildContext context) {
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
                  hintText: "请输入新手机号",
                  contentPadding: EdgeInsets.all(Dimensions.padding16),
                ),
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
                onChanged: (s) => logic.onNewPhoneNumberChanged(s),
              ),
            ),
          ),
          // SizedBox(width: Dimensions.margin16),
          // Container(
          //   height: Dimensions.button48,
          //   child: CupertinoButton(
          //     padding: EdgeInsets.symmetric(horizontal: Dimensions.padding16),
          //     onPressed: () async {},
          //     color: Theme.of(context).cardColor,
          //     child: Center(
          //       // TODO 先暂时仅支持+86，后续再支持更多的手机区号
          //       child: Text("+86"),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget buildSMSVerificationCodeTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "验证码",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildSMSVerificationCode(BuildContext context) {
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
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: "请输入验证码",
                  contentPadding: EdgeInsets.all(Dimensions.padding16),
                ),
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
                onChanged: (s) => logic.onSMSVerificationCodeChanged(s),
              ),
            ),
          ),
          SizedBox(width: Dimensions.margin16),
          Container(
            height: Dimensions.button60,
            child: Obx(
              () => CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: Dimensions.padding16),
                onPressed: () async {
                  logic.getSMSVerificationCode(context);
                },
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                child: Center(
                  child: Text(
                    "${state.textOfGetSMSVerificationCodeButton}",
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: CupertinoButton(
        minSize: Dimensions.button60,
        child: Text(
          "确认更换",
          style: TextStyle(
            fontSize: Dimensions.fontSize32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onPressed: () async {
          logic.changePhoneNumber(context);
        },
      ),
    );
  }
}
