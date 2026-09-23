import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/common/getx/controller/transaction_controller.dart';
import 'package:zheergen_merchant_end/common/models/transaction.dart';
import '../../../common/dimensions.dart';
import '../../../common/easy_refresh/my_phoenix_footer.dart';
import '../../../common/easy_refresh/my_phoenix_header.dart';
import '../../../common/exception/showable_exception.dart';
import '../../../common/models/transaction_type.dart';
import '../../../common/utility/toast.dart';
import '../../../common/widget/app_bar_scaffold.dart';
import '../../../common/widget/page_scaffold.dart';
import 'logic.dart';

class TransactionPage extends StatelessWidget {
  TransactionPage({Key? key}) : super(key: key);

  final logic = Get.put(TransactionLogic());
  final state = Get.find<TransactionLogic>().state;
  final transactionController = TransactionController.to;
  final merchant = MerchantController.to.merchant;
  final DateFormat transactionDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TransactionLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "账户流水",
          ),
          body: Column(
            children: [
              Expanded(
                child: buildTransactionList(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildTransactionList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
          Radius.circular(Dimensions.borderRadius12),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.only(
        left: Dimensions.margin16,
        right: Dimensions.margin16,
      ),
      child: EasyRefresh(
        canRefreshAfterNoMore: true,
        canLoadAfterNoMore: true,
        onRefresh: () async {
          try {
            await transactionController.fetchTransactions(isRefresh: true);
            showTextToast(context, "🥳 刷新成功");
            if (!transactionController.hasMore) {
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
          if (!transactionController.hasMore) {
            showTextToast(context, "😂 没有更多数据了哦！");
            return IndicatorResult.noMore;
          }
          try {
            await transactionController.fetchTransactions(isRefresh: false);
            showTextToast(context, "🥳 加载成功");
            if (!transactionController.hasMore) {
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
        controller: state.easyRefreshController,
        header: MyPhoenixHeader(
          context,
          position: IndicatorPosition.locator,
        ),
        footer: MyPhoenixFooter(
          context,
          position: IndicatorPosition.locator,
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
            // 列表
            Obx(
              () => transactionController.transactions.isEmpty
                  ? buildEmpty(context)
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return buildTransaction(
                            context,
                            transactionController.transactions[index],
                            index,
                          );
                        },
                        childCount: transactionController.transactions.length,
                      ),
                    ),
            ),
            // Footer
            SliverToBoxAdapter(
              child: SizedBox(
                height: Dimensions.padding16,
              ),
            ),
            const FooterLocator.sliver(),
          ],
        ),
      ),
    );
  }

  Widget buildTransaction(
    BuildContext context,
    Transaction transaction,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.only(
        top: index == 0 ? 0 : Dimensions.padding16,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${TransactionType.fromKey(transaction.type)?.localized(context)}",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Dimensions.margin16),
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                "金额：${transaction.amount > 0 ? "+${transaction.amount}" : transaction.amount}\n"
                "时间：${transactionDateFormat.format(transaction.createdAt!)}\n"
                "剩余可提现金额：${transaction.availableFundsAfter}\n"
                "备注：${transaction.description}",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: Dimensions.fontSize32,
                ),
              ),
            ),
            // TODO 配送单详情按钮
            // SizedBox(height: Dimensions.margin16),
            // CupertinoButton(
            //   minSize: Dimensions.button60,
            //   padding: EdgeInsets.only(
            //     left: Dimensions.padding16,
            //     right: Dimensions.padding16,
            //     top: Dimensions.padding16,
            //     bottom: Dimensions.padding16,
            //   ),
            //   borderRadius: BorderRadius.all(
            //     Radius.circular(Dimensions.borderRadius12),
            //   ),
            //   child: Row(
            //     children: [
            //       Expanded(
            //         child: Text(
            //           "配送订单详情",
            //           textAlign: TextAlign.left,
            //           style: TextStyle(
            //             fontSize: Dimensions.fontSize32,
            //           ),
            //         ),
            //       ),
            //       SizedBox(width: Dimensions.padding8),
            //       Icon(
            //         size: Dimensions.iconSize32,
            //         Icons.arrow_forward,
            //       ),
            //     ],
            //   ),
            //   onPressed: () async {
            //     // Get.to(TransactionPage());
            //   },
            //   color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            // ),
          ],
        ),
        onPressed: () async {},
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
      ),
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
              "还没有账户流水哦！😝",
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
}
