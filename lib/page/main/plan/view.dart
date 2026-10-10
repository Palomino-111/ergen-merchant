import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zheergen_merchant_end/common/easy_refresh/my_phoenix_footer.dart';
import 'package:zheergen_merchant_end/common/easy_refresh/my_phoenix_header.dart';
import 'package:zheergen_merchant_end/common/models/delivery_status.dart';
import 'package:zheergen_merchant_end/common/widget/page_scaffold.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/meal_delivery_order_list_controller.dart';
import 'package:zheergen_merchant_end/page/main/logic.dart';
import 'package:zheergen_merchant_end/common/widget/keep_alive_scaffold.dart';
import '../../../common/dimensions.dart';
import '../../../common/exception/showable_exception.dart';
import '../../../common/models/dish_sku.dart';
import '../../../common/models/dispatch_result.dart';
import '../../../common/models/meal.dart';
import '../../../common/models/meal_delivery_order.dart';
import '../../../common/utility/common.dart';
import '../../../common/utility/toast.dart';
import '../../../common/widget/app_bar_scaffold.dart';
import '../../../common/widget/blur_button.dart';
import '../../../common/widget/dialog/text_dialog.dart';
import 'logic.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({Key? key}) : super(key: key);

  @override
  PlanStatefulWidget createState() => PlanStatefulWidget();
}

class PlanStatefulWidget extends State<PlanPage>
    with AutomaticKeepAliveClientMixin {
  final logic = Get.put(PlanLogic());
  final state = Get.find<PlanLogic>().state;
  final mainLogic = Get.find<MainLogic>();
  final DateFormat planDateFormat = DateFormat('MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GetBuilder<PlanLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            leadingWidth: 0,
            leading: SizedBox(),
            title: buildTabBar(context),
            actions: [
              SizedBox(),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is OverscrollNotification) {
                      // 在**最后一个**分组 tab 上继续上滑 = 想去「我的」。
                      // 不写死 index：加减 tab 时这里最容易漏改
                      if (mainLogic.planTabController.index ==
                          mainLogic.planTabController.length - 1) {
                        mainLogic.mainTabController.animateTo(
                          1,
                          duration: const Duration(milliseconds: 500),
                        );
                      }
                    }
                    return true;
                  },
                  child: TabBarView(
                    controller: mainLogic.planTabController,
                    // physics: PageScrollPhysics(),
                    // tab 顺序 = orderControllers 顺序 = DeliveryStatusGroup 声明顺序
                    children: [
                      for (final MealDeliveryOrderListController controller
                          in logic.orderControllers)
                        KeepAliveScaffold(
                          child: buildOrderTab(context, controller),
                        ),
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

  Widget buildTabBar(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.only(
        left: Dimensions.margin16,
      ),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
      ),
      child: BackdropFilter(
        filter: buildImageFilter(),
        child: TabBar(
          controller: mainLogic.planTabController,
          dividerHeight: 0,
          tabAlignment: TabAlignment.start,
          labelPadding: EdgeInsets.zero,
          isScrollable: true,
          // 去掉水波纹效果
          overlayColor: WidgetStateProperty.all(Colors.transparent),
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
            for (final MealDeliveryOrderListController controller
                in logic.orderControllers)
              buildGroupTab(context, controller),
          ],
          indicatorColor: Theme.of(
            context,
          ).colorScheme.secondary,
        ),
      ),
    );
  }

  /// 一个分组 tab 的标题。
  ///
  /// 「待制作」带角标（商家最关心的就是还有多少单没做），
  /// 其余分组不带：角标要额外一次 count 请求，而它们不是待办。
  Widget buildGroupTab(
    BuildContext context,
    MealDeliveryOrderListController controller,
  ) {
    final DeliveryStatusGroup group = controller.group;
    final TextStyle textStyle = TextStyle(
      fontSize: Dimensions.fontSize32,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Container(
      height: Dimensions.button60,
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        left: Dimensions.margin16,
        right: Dimensions.margin16,
      ),
      child: group.countBadge
          ? Obx(
              () => Text(
                '${group.label}（${controller.count}单）',
                style: textStyle,
              ),
            )
          : Text(group.label, style: textStyle),
    );
  }

  @override
  bool get wantKeepAlive => true;

  /**
   * 一个分组的订单列表。
   *
   * 三个 tab 共用这一份实现：分组之间的差异（status 集合、排序方向、
   * 要不要角标、文案）全部来自 [MealDeliveryOrderListController.group]，
   * 所以这里没有一行「这是哪个 tab」的判断。
   *
   */
  Widget buildOrderTab(
    BuildContext context,
    MealDeliveryOrderListController controller,
  ) {
    final EasyRefreshController easyRefreshController =
        state.easyRefreshControllers[controller.group]!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: EasyRefresh(
        refreshOnStart: true,
        canRefreshAfterNoMore: true,
        canLoadAfterNoMore: true,
        onRefresh: () async {
          try {
            await controller.fetchMealDeliveryOrders(isRefresh: true);
            showTextToast(context, "🥳 刷新成功");
            if (!controller.hasMore) {
              return IndicatorResult.noMore;
            }
            return IndicatorResult.success;
          } on ShowableException catch (e) {
            showTextToast(context, e.message);
          } catch (e) {
            showTextToast(context, "未知错误");
          }
          return IndicatorResult.fail;
        },
        onLoad: () async {
          if (!controller.hasMore) {
            showTextToast(context, "😂 没有更多数据了哦！");
            return IndicatorResult.noMore;
          }
          try {
            await controller.fetchMealDeliveryOrders(isRefresh: false);
            showTextToast(context, "🥳 加载成功");
            if (!controller.hasMore) {
              return IndicatorResult.noMore;
            }
            return IndicatorResult.success;
          } on ShowableException catch (e) {
            showTextToast(context, e.message);
          } catch (e) {
            showTextToast(context, "未知错误");
          }
          return IndicatorResult.fail;
        },
        controller: easyRefreshController,
        header: MyPhoenixHeader(
          context,
          position: IndicatorPosition.locator,
          margin: EdgeInsets.only(
            left: Dimensions.padding16,
            right: Dimensions.padding16,
          ),
        ),
        footer: MyPhoenixFooter(
          context,
          position: IndicatorPosition.locator,
          margin: EdgeInsets.only(
            left: Dimensions.padding16,
            right: Dimensions.padding16,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // 状态栏 + 导航栏占位
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.top +
                    AppBarScaffold.appBarHeight,
              ),
            ),
            // Header
            const HeaderLocator.sliver(),
            Obx(
              () => controller.orders.isEmpty
                  ? buildEmpty(context, controller.group.emptyText)
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return buildMealDeliveryOrder(
                            context,
                            controller.orders[index],
                            index,
                            showStatus: controller.group.showItemStatus,
                          );
                        },
                        childCount: controller.orders.length,
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: Dimensions.padding16,
              ),
            ),
            const FooterLocator.sliver(),
            // 底部导航栏占位
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom +
                    Dimensions.padding16 +
                    Dimensions.padding16 * 2 +
                    Dimensions.button60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMealDeliveryOrder(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
    int index, {
    // 同一个分组内状态是恒定的，展示「配送状态」是纯噪音；
    // 只有「已结束」组混着已送达/已收货/已取消才需要（见 DeliveryStatusGroup）
    required bool showStatus,
  }) {
    final deliveryStatus = DeliveryStatus.fromKey(mealDeliveryOrder.status);
    final notShowDispatchButton =
        deliveryStatus != DeliveryStatus.awaitingPreparation &&
            deliveryStatus != DeliveryStatus.preparing;
    final bool isCancelled = deliveryStatus == DeliveryStatus.cancelled;
    final Widget card = Container(
      padding: EdgeInsets.only(
        top: index == 0 ? 0 : Dimensions.padding16,
        left: Dimensions.padding16,
        right: Dimensions.padding16,
      ),
      child: CupertinoButton(
        minSize: Dimensions.button60,
        padding: EdgeInsets.only(
          left: Dimensions.padding16,
          right: Dimensions.padding16,
          top: Dimensions.padding16,
          bottom: Dimensions.padding16,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
        child: Column(
          children: [
            // 预计送达时间
            Row(
              children: [
                Expanded(
                  // TODO(li): 出餐时间（出餐时间 = 用户用餐时间/送达时间 - 配送所需时间 - 出餐时间buffer【5分钟】），先暂时直接使用预计送达时间
                  child: Text(
                    "预计送达：${planDateFormat.format(mealDeliveryOrder.deliveryTime)}",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
              ],
            ),
            // 联系客户
            SizedBox(height: Dimensions.margin16),
            CupertinoButton(
              minSize: Dimensions.button60,
              padding: EdgeInsets.only(
                left: Dimensions.padding16,
                right: Dimensions.padding16,
                top: Dimensions.padding16,
                bottom: Dimensions.padding16,
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(Dimensions.borderRadius12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "联系客户",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  SizedBox(width: Dimensions.padding8),
                  Icon(
                    size: Dimensions.iconSize32,
                    Icons.phone_forwarded,
                  ),
                ],
              ),
              onPressed: () async {
                canLaunchUrl(
                  Uri(
                    scheme: 'tel',
                    path: mealDeliveryOrder.phone,
                  ),
                ).then((bool hasCallSupport) {
                  if (!hasCallSupport) {
                    showTextToast(context, "发生异常，请手动拨打");
                    return;
                  }
                  makePhoneCall(
                    mealDeliveryOrder.phone,
                  );
                });
              },
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
            // Meal信息
            SizedBox(height: Dimensions.margin16),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                "菜品列表：",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: Dimensions.fontSize32,
                ),
              ),
            ),
            // 派单（呼叫骑手）
            if (!notShowDispatchButton)
              SizedBox(height: Dimensions.margin16),
            if (!notShowDispatchButton)
              buildDispatchButton(context, mealDeliveryOrder),
            // 菜品列表
            SizedBox(height: Dimensions.margin16),
            // 列表接口已经把 meal / dish_sku 嵌套查回来了，直接用，避免每个 item
            // 再单独查一次餐品（N+1）；只有 meal 关联缺失时才回退到单独查询
            if (mealDeliveryOrder.meal != null)
              buildFoods(mealDeliveryOrder.meal!)
            else if (mealDeliveryOrder.mealId != null)
              FutureBuilder<Meal?>(
                future:
                    logic.mealRepository.getOneById(mealDeliveryOrder.mealId!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Text("加载中...");
                  }
                  final meal = snap.data;
                  if (snap.hasError || meal == null) {
                    return const Text('菜品获取失败!');
                  }
                  return buildFoods(meal);
                },
              )
            else
              const Text('菜品获取失败!'),
            // 配送状态
            if (showStatus) ...[
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "配送状态：${deliveryStatus?.localized(context)}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
            // 配送订单id
            SizedBox(height: Dimensions.margin16),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                "配送订单ID：${mealDeliveryOrder.id}",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: Dimensions.fontSize32,
                ),
              ),
            ),
            // 复制
            SizedBox(height: Dimensions.margin16),
            CupertinoButton(
              minSize: Dimensions.button60,
              padding: EdgeInsets.only(
                left: Dimensions.padding16,
                right: Dimensions.padding16,
                top: Dimensions.padding16,
                bottom: Dimensions.padding16,
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(Dimensions.borderRadius12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "复制",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
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
                    text: mealDeliveryOrder.id!,
                  ),
                );
                showTextToast(context, "复制成功");
              },
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),
          ],
        ),
        onPressed: () async {},
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
    );
    // 取消单和正常完成的单在「已结束」里混排，压暗一档才分得出来。
    // 用 Opacity 而不是逐个改文字/按钮颜色：卡片里还有按钮，改样式要改一圈
    return isCancelled ? Opacity(opacity: 0.5, child: card) : card;
  }

  /**
   * 派单按钮（呼叫骑手）
   *
   * 注意：点击后会向骑手下发**真实运力订单并产生真实费用**，
   * 所以这里不直接发请求，必须先弹二次确认
   */
  CupertinoButton buildDispatchButton(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
  ) {
    return CupertinoButton(
      minSize: Dimensions.button60,
      padding: EdgeInsets.only(
        left: Dimensions.padding16,
        right: Dimensions.padding16,
        top: Dimensions.padding16,
        bottom: Dimensions.padding16,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(Dimensions.borderRadius12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "派单",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          SizedBox(width: Dimensions.padding8),
          Icon(
            size: Dimensions.iconSize32,
            Icons.send,
          ),
        ],
      ),
      onPressed: () async {
        showConfirmDispatchAlertDialog(
          context,
          mealDeliveryOrder,
        );
      },
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
    );
  }

  /// 空列表占位。文案按分组传（空 tab 现在很常见，一句通用的「没有订单」
  /// 会让商家分不清是「真的没单」还是「这一组本来就没内容」）
  Widget buildEmpty(BuildContext context, String text) {
    return SliverToBoxAdapter(
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.all(
          Dimensions.margin16,
        ),
        child: AnimatedTextKit(
          animatedTexts: [
            TyperAnimatedText(
              text,
              textStyle: TextStyle(
                fontSize: Dimensions.fontSize32,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              speed: Duration(milliseconds: 100),
              curve: Curves.fastEaseInToSlowEaseOut,
            ),
          ],
          totalRepeatCount: 1,
          displayFullTextOnTap: true,
        ),
      ),
    );
  }

  Widget buildFoods(Meal meal) {
    final List<DishSku>? dishSkus = meal.dishSkus;
    if (dishSkus == null || dishSkus.isEmpty) {
      return SizedBox();
    }
    return Container(
      width: double.infinity,
      child: Wrap(
        spacing: Dimensions.padding16,
        runSpacing: Dimensions.padding16,
        children: <Widget>[
          ...List.generate(
            dishSkus.length,
            (index) {
              return BlurButton(
                // TODO 给dish_sku加上图片
                imageProvider: /*dishSkus[index].image != null
                    ? NetworkImage(dishSkus[index].image ?? '')
                    :*/
                    AssetImage('assets/test.jpeg'),
                child: CupertinoButton(
                  minSize: Dimensions.button60,
                  onPressed: () async {},
                  child: Text(
                    '${dishSkus[index].name}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /**
   * 确认派单（呼叫骑手）
   *
   * 这一步会花**真钱**：服务端会向快递100 下发真实运力订单并扣费，
   * 所以内容上必须明确告知费用，逻辑上任何情况都不要自动重试
   */
  Future<void> showConfirmDispatchAlertDialog(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
  ) async {
    showDialog<String>(
      context: context,
      builder: (context) => TextDialog(
        title: "确认呼叫骑手？",
        content: "将向骑手派发真实运力订单，并产生真实配送费用。",
        actions: [
          CupertinoButton(
            minSize: Dimensions.button60,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            child: Text(
              "确认派单",
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
      if (value != 'confirm') return;

      // 状态检查
      // 列表数据可能是几分钟前拉的，用户点的时候服务端状态可能早变了
      // 只有 awaiting_preparation / preparing 可发单；
      // awaiting_delivery 是派单成功后的目标状态，放行它等于允许重复派单（重复扣费）
      final status = DeliveryStatus.fromKey(mealDeliveryOrder.status);
      if (status != DeliveryStatus.awaitingPreparation &&
          status != DeliveryStatus.preparing) {
        showTextToast(
          context,
          "状态错误！\n"
          "当前状态：${status?.localized(context)}",
        );
        return;
      }

      // 派单。失败时 logic 内部已经提示过了，返回 null 表示没成功
      final DispatchResult? result = await logic.dispatchMealDeliveryOrder(
        context,
        mealDeliveryOrder,
      );

      // await 之后当前页面可能已经被销毁，用 context 前必须检查
      if (!context.mounted) return;
      if (result == null) return;

      showTextToast(
        context,
        result.alreadyDispatched ? "该单已派过，本次未重复下单" : "🥳 派单成功",
      );

      // 局部更新这一项，不要整体刷新列表。
      //
      // 走控制器的按 id 更新，而不是像以前那样按下标直接赋值：
      // 现在有 Realtime 订阅，这一条可能已经被推送先一步从「待制作」里移除了，
      // 那时候按下标赋值要么越界崩溃、要么覆盖到别的单单。
      // 按 id 找不到就什么都不做，天然幂等，也不会重复扣角标。
      logic.toPrepareController.applyDispatched(
        mealDeliveryOrder.id,
        result.status,
      );
    });
  }
}
