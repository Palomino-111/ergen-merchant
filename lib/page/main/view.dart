import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/utility/common.dart';
import '../../common/dimensions.dart';
import '../../common/push/tpns_service.dart';
import '../../common/widget/page_scaffold.dart';
import 'logic.dart';
import 'my/view.dart';
import 'plan/view.dart';

/// 主页面：生产计划 + 我的，两个 tab。
///
/// 改成 StatefulWidget 的原因：需要在首帧之后消费「冷启动被通知拉起」时
/// TpnsService 暂存的 pending orderId。StatelessWidget 没有生命周期钩子，
/// 硬塞在 build 里会每次重建都触发一次跳转。
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final logic = Get.put(MainLogic());
  final state = Get.find<MainLogic>().state;

  @override
  void initState() {
    super.initState();
    // 首帧之后才消费 pending：TabController.animateTo 要求 controller
    // 已经 attach 到 TabBarView（首帧 build 完成才算），否则跳转会无效。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingOrderId = TpnsService.I.consumePendingOrderId();
      if (pendingOrderId != null && mounted) {
        logic.jumpToPendingOrder(pendingOrderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      body: Stack(
        children: [
          TabBarView(
            controller: logic.mainTabController,
            // TODO 由于有两层TabBarView嵌套，会导致回弹效果在外层会失效，
            // 尝试了一下使用NestedScrollView，没解决，后续再看一下怎么处理，
            // 所以先把回弹效果向都去掉，让内外保持一致
            // physics: BouncingScrollPhysics(),
            children: [
              PlanPage(),
              // TODO 测试版本先暂时不管订单管理 只需要生成计划就够了 后续慢慢迭代
              // OrderPage(),
              MyPage(),
            ],
          ),
          buildTabBar(context),
        ],
      ),
    );
  }

  Widget buildTabBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      width: MediaQuery.of(context).size.width,
      child: Container(
        margin: EdgeInsets.all(
          Dimensions.margin16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.circular(Dimensions.borderRadius12),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: BackdropFilter(
          filter: buildImageFilter(),
          child: Container(
            padding: EdgeInsets.all(
              Dimensions.padding16,
            ),
            width: MediaQuery.of(context).size.width,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.1),
            child: TabBar(
              controller: logic.mainTabController,
              labelPadding: EdgeInsets.only(
                left: Dimensions.padding16,
                right: Dimensions.padding16,
              ),
              isScrollable: true,
              indicatorWeight: 0,
              indicator: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Dimensions.borderRadius12,
                  ),
                ),
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.1),
              ),
              tabs: [
                Container(
                  height: Dimensions.button60,
                  alignment: Alignment.center,
                  child: Text(
                    "生产计划",
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                // TODO 测试版本先暂时不管订单管理 只需要生成计划就够了 后续慢慢迭代
                // Container(
                //   height: Dimensions.button60,
                //   alignment: Alignment.center,
                //   child: Text(
                //     "订单管理",
                //     style: TextStyle(
                //       fontSize: Dimensions.fontSize32,
                //       color: Theme.of(context).colorScheme.onSurface,
                //     ),
                //   ),
                // ),
                Container(
                  height: Dimensions.button60,
                  alignment: Alignment.center,
                  child: Text(
                    "我的",
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}