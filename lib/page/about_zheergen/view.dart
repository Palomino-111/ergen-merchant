import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common/dimensions.dart';
import '../../common/utility/common.dart';
import '../../common/utility/toast.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../../common/widget/page_scaffold.dart';
import '../web_view/view.dart';
import 'logic.dart';
import 'state.dart';

class AboutZheergenPage extends StatelessWidget {
  AboutZheergenPage({Key? key}) : super(key: key);

  final logic = Get.put(AboutZheergenLogic());
  final state = Get.find<AboutZheergenLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AboutZheergenLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "关于折耳根",
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: Dimensions.margin16,
                    // 状态栏 + AppBar占位
                    top: MediaQuery.of(context).padding.top +
                        AppBarScaffold.appBarHeight -
                        Dimensions.margin16,
                    right: Dimensions.margin16,
                    bottom: Dimensions.margin16 * 2 +
                        Dimensions.button60 +
                        Dimensions.margin16 * 2,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      buildApplicationInformation(context),
                      Container(
                        margin: EdgeInsets.only(top: Dimensions.margin16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "官方网站",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize32,
                          ),
                        ),
                      ),
                      buildOfficialWebsite(context),
                      buildContactUs(context),
                      Container(
                        margin: EdgeInsets.only(top: Dimensions.margin16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "其它",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize32,
                          ),
                        ),
                      ),
                      buildPrivacyPolicy(context),
                      buildUserAgreement(context),
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

  Widget buildContactUs(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: Dimensions.margin16),
            alignment: Alignment.centerLeft,
            child: Text(
              "联系我们",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          SizedBox(
            height: Dimensions.padding16,
          ),
          ClipRRect(
            child: Container(
              child: Column(
                children: [
                  CupertinoButton(
                    minSize: Dimensions.button60,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.1),
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
                            "客服QQ（${AboutZheergenState.customerServiceQQ}）",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: Dimensions.fontSize24,
                            ),
                          ),
                        ),
                        Text(
                          "复制",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize24,
                          ),
                        ),
                        SizedBox(width: Dimensions.padding8),
                        Icon(
                          size: Dimensions.iconSize32,
                          Icons.copy,
                        ),
                      ],
                    ),
                    onPressed: () async {
                      Clipboard.setData(
                        ClipboardData(
                          text: AboutZheergenState.customerServiceQQ,
                        ),
                      );
                      showTextToast(context, "复制成功");
                    },
                  ),
                  SizedBox(height: Dimensions.padding16),
                  CupertinoButton(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.1),
                    minSize: Dimensions.button60,
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
                            "官方QQ群（${AboutZheergenState.customerServiceQQGroup}）",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: Dimensions.fontSize24,
                            ),
                          ),
                        ),
                        Text(
                          "复制",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize24,
                          ),
                        ),
                        SizedBox(width: Dimensions.padding8),
                        Icon(
                          size: Dimensions.iconSize32,
                          Icons.copy,
                        ),
                      ],
                    ),
                    onPressed: () async {
                      Clipboard.setData(
                        ClipboardData(
                          text: AboutZheergenState.customerServiceQQGroup,
                        ),
                      );
                      showTextToast(context, "复制成功");
                    },
                  ),
                  SizedBox(height: Dimensions.padding16),
                  CupertinoButton(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.1),
                    minSize: Dimensions.button60,
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
                            "客服微信（${AboutZheergenState.customerServiceWechat}）",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: Dimensions.fontSize24,
                            ),
                          ),
                        ),
                        Text(
                          "复制",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize24,
                          ),
                        ),
                        SizedBox(width: Dimensions.padding8),
                        Icon(
                          size: Dimensions.iconSize32,
                          Icons.copy,
                        ),
                      ],
                    ),
                    onPressed: () async {
                      Clipboard.setData(
                        ClipboardData(
                          text: AboutZheergenState.customerServiceWechat,
                        ),
                      );
                      showTextToast(context, "复制成功");
                    },
                  ),
                  SizedBox(height: Dimensions.padding16),
                  CupertinoButton(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.1),
                    minSize: Dimensions.button60,
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
                            "客服电话（${AboutZheergenState.customerServiceTelephoneNumbers}）",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: Dimensions.fontSize24,
                            ),
                          ),
                        ),
                        Text(
                          "拨打",
                          style: TextStyle(
                            fontSize: Dimensions.fontSize24,
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
                      canLaunchUrl(
                        Uri(
                          scheme: 'tel',
                          path: AboutZheergenState
                              .customerServiceTelephoneNumbers,
                        ),
                      ).then((bool hasCallSupport) {
                        if (!hasCallSupport) {
                          showTextToast(context, "发生异常，请手动拨打");
                          return;
                        }
                        makePhoneCall(
                          AboutZheergenState.customerServiceTelephoneNumbers,
                        );
                      });
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

  Widget buildUserAgreement(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
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
                "用户协议",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            Icon(
              size: Dimensions.iconSize32,
              Icons.arrow_forward,
            ),
          ],
        ),
        onPressed: () async {
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
    );
  }

  Widget buildPrivacyPolicy(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
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
                "隐私政策",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            Icon(
              size: Dimensions.iconSize32,
              Icons.arrow_forward,
            ),
          ],
        ),
        onPressed: () async {
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
    );
  }

  Widget buildOfficialWebsite(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      child: CupertinoButton(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
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
                "www.zheergen.com",
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                ),
              ),
            ),
            Icon(
              size: Dimensions.iconSize32,
              Icons.arrow_forward,
            ),
          ],
        ),
        onPressed: () async {
          Get.to(
            WebViewPage(),
            arguments: {
              "uri": Uri.parse("http://www.flomozzr.com/dist"),
              "title": "www.zheergen.com"
            },
          );
        },
      ),
    );
  }

  Widget buildApplicationInformation(BuildContext context) {
    var appIconSize = MediaQuery.of(context).size.width / 3;
    return Container(
      margin: EdgeInsets.only(top: Dimensions.margin16),
      child: Column(
        children: [
          // 应用图标
          Container(
            height: appIconSize,
            width: appIconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(Dimensions.borderRadius12),
              ),
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
            child: Text(
              "折耳根",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 版本号
          Container(
            margin: EdgeInsets.only(top: Dimensions.margin16),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: Dimensions.fontSize24,
                  color: Colors.grey,
                ),
                children: [
                  TextSpan(
                    text: "当前版本：",
                  ),
                  TextSpan(
                    text: "${state.packageInfo.value?.version ?? "null"}",
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
