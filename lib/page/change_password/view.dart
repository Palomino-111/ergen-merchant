import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/dimensions.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../../common/widget/bottom_bar_scaffold.dart';
import '../../common/widget/page_scaffold.dart';
import 'logic.dart';

class ChangePasswordPage extends StatelessWidget {
  ChangePasswordPage({Key? key}) : super(key: key);

  final logic = Get.put(ChangePasswordLogic());
  final state = Get.find<ChangePasswordLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChangePasswordLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "修改密码",
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
                        // 新密码
                        buildPasswordTitle(),
                        buildPassword(context),
                        buildPasswordHint(),
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

  Widget buildPasswordTitle() {
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      alignment: Alignment.centerLeft,
      child: Text(
        "新的密码",
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
                    hintText: "请输入新的密码",
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

  Widget buildPasswordHint() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: Dimensions.margin16),
      child: Text(
        "请设置 8-32 位包含数字、字母的密码",
        style: TextStyle(
          fontSize: Dimensions.fontSize24,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: CupertinoButton(
        minSize: Dimensions.button60,
        child: Text(
          "修改密码",
          style: TextStyle(
            fontSize: Dimensions.fontSize32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onPressed: () async {
          logic.changePassword(context);
        },
        // color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
      ),
    );
  }
}
