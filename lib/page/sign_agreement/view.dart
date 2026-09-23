import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../common/dimensions.dart';
import '../../common/hive_names.dart';
import '../../common/widget/bottom_bar_scaffold.dart';
import '../../common/widget/page_scaffold.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../main/view.dart';
import '../web_view/view.dart';
import 'logic.dart';

class SignAgreementPage extends StatelessWidget {
  SignAgreementPage({Key? key}) : super(key: key);

  final logic = Get.put(SignAgreementLogic());
  final state = Get.find<SignAgreementLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SignAgreementLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            leading: Row(
              children: [
                SizedBox(
                  width: Dimensions.margin16,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Dimensions.borderRadius12,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: CupertinoButton(
                      borderRadius: BorderRadius.all(
                        Radius.circular(Dimensions.borderRadius12),
                      ),
                      color: Colors.white.withOpacity(0.1),
                      minSize: Dimensions.button60,
                      padding: EdgeInsets.zero,
                      child: Icon(
                        Icons.arrow_back,
                      ),
                      onPressed: () async {
                        SystemNavigator.pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
            titleString: "欢迎使用折耳根",
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
                      SizedBox(
                        height: Dimensions.padding16,
                      ),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Dimensions.fontSize24,
                          ),
                          children: [
                            TextSpan(
                              text: '感谢您信任并使用折耳根!我们将通过',
                            ),
                            TextSpan(
                              text: '《用户协议》',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
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
                                color: Theme.of(context).colorScheme.secondary,
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
                            TextSpan(
                              text:
                                  '帮助您了解我们收集、使用、存储和共享个人信息的情况,特别是我们所采集的个人信息类型与用途的对应关系。此外,您还能了解到您所享有的相关权利及实现途径。如您同意,请点击下方按钮开始接受我们的服务。',
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: Container(
        margin: EdgeInsets.all(
          Dimensions.margin16,
        ),
        height: Dimensions.button60,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: double.infinity,
                child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.all(
                      Radius.circular(Dimensions.borderRadius12),
                    ),
                    child: Text(
                      "不同意",
                      style: TextStyle(
                        fontSize: Dimensions.fontSize24,
                      ),
                    ),
                    onPressed: () async {
                      SystemNavigator.pop();
                    },
                    color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            SizedBox(width: Dimensions.padding16),
            Expanded(
              child: Container(
                height: double.infinity,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.all(
                    Radius.circular(Dimensions.borderRadius12),
                  ),
                  child: Text(
                    "同意",
                    style: TextStyle(
                      fontSize: Dimensions.fontSize24,
                    ),
                  ),
                  onPressed: () async {
                    Hive.box(HiveNames.settings).put(
                      'userHasSignedTheRelevantAgreement',
                      true,
                    );
                    Get.off(MainPage());
                  },
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
