import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../common/widget/page_scaffold.dart';
import '../../common/widget/app_bar_scaffold.dart';
import 'logic.dart';

class WebViewPage extends StatelessWidget {
  WebViewPage({Key? key}) : super(key: key);

  final logic = Get.put(WebViewLogic());
  final state = Get.find<WebViewLogic>().state;

  @override
  Widget build(BuildContext context) {
    final String title = Get.arguments['title'];
    final Uri uri = Get.arguments['uri'];
    logic.initWebEngin(context);
    state.webViewController?..loadRequest(uri);
    return GetBuilder<WebViewLogic>(
      assignId: true,
      builder: (logic) {
        // TODO 通用导航栏实现
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: title,
          ),
          body: Container(
            padding: EdgeInsets.only(
              // left: Dimensions.margin16,

              // 状态栏占位 + AppBar占位
              top: MediaQuery.of(context).padding.top +
                  AppBarScaffold.appBarHeight /*- Dimensions.margin16*/,
              // right: Dimensions.margin16,
              // bottom: Dimensions.margin16 * 2 +
              //     Dimensions.button60 +
              //     Dimensions.margin16 * 2,
            ),
            child: WebViewWidget(controller: state.webViewController!),
          ),
        );
      },
    );
  }
}
