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
                      if (mainLogic.planTabController.index == 1) {
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
                    children: [
                      KeepAliveScaffold(
                        child: buildAwaitingPreparationMealDeliveryOrderList(
                          context,
                        ),
                      ),
                      KeepAliveScaffold(
                        child: buildAllMealDeliveryOrderList(context),
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
            Container(
              height: Dimensions.button60,
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                left: Dimensions.margin16,
                right: Dimensions.margin16,
              ),
              // TODO 这里的数据是不对的，展示的时已经拉下来的数据，而不是总数，应该拿到的时候该商家的待制作数据的总数
              child: Obx(
                () => Text(
                  '待制作（${logic.awaitingPreparationMealDeliveryOrderController.count}单）',
                  style: TextStyle(
                    fontSize: Dimensions.fontSize32,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Container(
              height: Dimensions.button60,
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                left: Dimensions.margin16,
                right: Dimensions.margin16,
              ),
              child: Text(
                '全部',
                style: TextStyle(
                  fontSize: Dimensions.fontSize32,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
          indicatorColor: Theme.of(
            context,
          ).colorScheme.secondary,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  /**
   * 待制作餐配送列表
   */
  Widget buildAwaitingPreparationMealDeliveryOrderList(BuildContext context) {
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
            await logic.awaitingPreparationMealDeliveryOrderController
                .fetchMealDeliveryOrders(isRefresh: true);
            showTextToast(context, "🥳 刷新成功");
            if (!logic.awaitingPreparationMealDeliveryOrderController.hasMore) {
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
          if (!logic.awaitingPreparationMealDeliveryOrderController.hasMore) {
            showTextToast(context, "😂 没有更多数据了哦！");
            return IndicatorResult.noMore;
          }
          try {
            await logic.awaitingPreparationMealDeliveryOrderController
                .fetchMealDeliveryOrders(isRefresh: false);
            showTextToast(context, "🥳 加载成功");
            if (!logic.awaitingPreparationMealDeliveryOrderController.hasMore) {
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
        controller: state.awaitingPreparationEasyRefreshController,
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
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return buildMealDeliveryOrder(
                      context,
                      logic.awaitingPreparationMealDeliveryOrderController
                          .awaitingPreparationMealDeliveryOrders[index],
                      index,
                    );
                  },
                  childCount: logic
                      .awaitingPreparationMealDeliveryOrderController
                      .awaitingPreparationMealDeliveryOrders
                      .length,
                ),
              ),
              // () => logic.awaitingPreparationMealDeliveryOrderController
              //         .awaitingPreparationMealDeliveryOrders.isEmpty
              //     ? buildEmpty(context)
              //     : SliverList(
              //         delegate: SliverChildBuilderDelegate(
              //           (context, index) {
              //             return buildMealDeliveryOrder(
              //               context,
              //               logic.awaitingPreparationMealDeliveryOrderController
              //                   .awaitingPreparationMealDeliveryOrders[index],
              //               index,
              //             );
              //           },
              //           childCount: logic
              //               .awaitingPreparationMealDeliveryOrderController
              //               .awaitingPreparationMealDeliveryOrders
              //               .length,
              //         ),
              //       ),
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

  /**
   * 全部餐配送订单列表
   */
  Widget buildAllMealDeliveryOrderList(BuildContext context) {
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
            await logic.allMealDeliveryOrderController.fetchMealDeliveryOrders(
              isRefresh: true,
            );
            showTextToast(context, "🥳 刷新成功");
            if (!logic.allMealDeliveryOrderController.hasMore) {
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
          if (!logic.allMealDeliveryOrderController.hasMore) {
            showTextToast(context, "😂 没有更多数据了哦！");
            return IndicatorResult.noMore;
          }
          try {
            await logic.allMealDeliveryOrderController.fetchMealDeliveryOrders(
              isRefresh: false,
            );
            showTextToast(context, "🥳 加载成功");
            if (!logic.allMealDeliveryOrderController.hasMore) {
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
        controller: state.allEasyRefreshController,
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
              () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return buildMealDeliveryOrder(
                      context,
                      logic.allMealDeliveryOrderController
                          .allMealDeliveryOrders[index],
                      index,
                    );
                  },
                  childCount: logic.allMealDeliveryOrderController
                      .allMealDeliveryOrders.length,
                ),
              ),
              // () => logic.allMealDeliveryOrderController.allMealDeliveryOrders
              //         .isEmpty
              //     ? buildEmpty(context)
              //     : SliverList(
              //         delegate: SliverChildBuilderDelegate(
              //           (context, index) {
              //             return buildMealDeliveryOrder(
              //               context,
              //               logic.allMealDeliveryOrderController
              //                   .allMealDeliveryOrders[index],
              //               index,
              //             );
              //           },
              //           childCount: logic.allMealDeliveryOrderController
              //               .allMealDeliveryOrders.length,
              //         ),
              //       ),
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
    int index,
  ) {
    final deliveryStatus = DeliveryStatus.fromKey(mealDeliveryOrder.status);
    final notShowStartDeliveryButton =
        deliveryStatus != DeliveryStatus.awaitingPreparation &&
            deliveryStatus != DeliveryStatus.preparing;
    return Container(
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
            // 开始配送
            if (!notShowStartDeliveryButton)
              SizedBox(height: Dimensions.margin16),
            if (!notShowStartDeliveryButton)
              buildStartDeliveryButton(context, mealDeliveryOrder, index),
            // 派单（呼叫骑手）
            if (!notShowStartDeliveryButton)
              SizedBox(height: Dimensions.margin16),
            if (!notShowStartDeliveryButton)
              buildDispatchButton(context, mealDeliveryOrder, index),
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
  }

  CupertinoButton buildStartDeliveryButton(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
    int index,
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
              "开始配送",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          SizedBox(width: Dimensions.padding8),
          Icon(
            size: Dimensions.iconSize32,
            Icons.delivery_dining,
          ),
        ],
      ),
      onPressed: () async {
        showConfirmStartDeliveryAlertDialog(
          context,
          mealDeliveryOrder,
          index,
        );
      },
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
    );
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
    int index,
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
          index,
        );
      },
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
    );
  }

  Widget buildEmpty(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.all(
          Dimensions.margin16,
        ),
        child: AnimatedTextKit(
          animatedTexts: [
            TyperAnimatedText(
              "没有订单！😝",
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

  Future<void> showConfirmStartDeliveryAlertDialog(
    BuildContext context,
    MealDeliveryOrder mealDeliveryOrder,
    int index,
  ) async {
    showDialog<String>(
      context: context,
      builder: (context) => TextDialog(
        title: "确认开始配送？",
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
        final status = DeliveryStatus.fromKey(mealDeliveryOrder.status);
        // 状态检查
        if (status != DeliveryStatus.awaitingPreparation &&
            status != DeliveryStatus.preparing) {
          showTextToast(
            context,
            "状态错误！\n"
            "当前状态：${status?.localized(context)}",
          );
          return;
        }
        // 深拷贝 并 改状态为待配送
        final newMealDeliveryOrder = mealDeliveryOrder.copyWith(
          status: DeliveryStatus.awaitingDelivery.key,
        );
        // 更新配送订单状态
        bool isSuccess = await logic.updateMealDeliveryOrder(
          context,
          newMealDeliveryOrder,
        );
        if (isSuccess) {
          // fixme 这种方式好像可以实现局部更新，测试一下，解决局部更新问题，当然，多个Tab时这里可以直接用removeWhere解决更好
          // logic.mealDeliveryOrderController.mealDeliveryOrders.replaceRange(
          //   index,
          //   index,
          //   [newMealDeliveryOrder],
          // );
          logic.awaitingPreparationMealDeliveryOrderController
                  .awaitingPreparationMealDeliveryOrders[index] =
              newMealDeliveryOrder;
          // 手动-1，就不浪费服务端资源了
          logic.awaitingPreparationMealDeliveryOrderController.count.value -= 1;
        }
      }
    });
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
    int index,
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

      // 局部更新这一项，不要整体刷新列表
      final controller = logic.awaitingPreparationMealDeliveryOrderController;
      controller.awaitingPreparationMealDeliveryOrders[index] =
          mealDeliveryOrder.copyWith(status: result.status);
      // 派单后状态变为 awaiting_delivery，已不属于「待制作」，手动-1
      // 幂等返回时不减：那种情况下这单本来就不该在待制作列表里（是本地数据陈旧）
      if (!result.alreadyDispatched) {
        controller.count.value -= 1;
      }
    });
  }
}
