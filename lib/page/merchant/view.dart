import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/page/merchant/transaction/view.dart';
import 'package:zheergen_merchant_end/page/merchant/withdrawal_account/view.dart';
import '../../common/dimensions.dart';
import '../../common/widget/app_bar_scaffold.dart';
import '../../common/widget/page_scaffold.dart';
import 'logic.dart';

class MerchantPage extends StatelessWidget {
  MerchantPage({Key? key}) : super(key: key);

  final logic = Get.put(MerchantLogic());
  final state = Get.find<MerchantLogic>().state;
  final merchant = MerchantController.to.merchant;
  final funds = MerchantController.to.funds;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MerchantLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "店铺",
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
                      // 店铺信息
                      buildMerchantInformation(context),
                      // 资金管理
                      buildFundManagement(context),
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

  Widget buildMerchantInformation(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: Dimensions.margin16),
            alignment: Alignment.centerLeft,
            child: Text(
              "店铺信息",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            child: Container(
              child: Column(
                children: [
                  // TODO 测试版本只展示，先跑起来后慢慢迭代，增加修改等功能
                  // 名称
                  buildName(context),
                  // id
                  buildId(context),
                  // TODO 测试版本只展示，先跑起来后慢慢迭代，增加修改等功能
                  // 联系方式
                  buildPhoneNumber(context),
                  // TODO 测试版本只展示，先跑起来后慢慢迭代，增加修改等功能
                  // 地址
                  buildAddress(context),
                  // TODO 测试版本先不需要，后续版本再慢慢加上
                  // 营业状态
                  // buildBusinessStatus(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFundManagement(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: Dimensions.margin16),
            alignment: Alignment.centerLeft,
            child: Text(
              "资金管理",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            child: Container(
              child: Column(
                children: [
                  // 提现账号
                  buildWithdrawalAccount(context),
                  // 账户流水
                  buildAccountStatement(context),
                  // 资金信息
                  buildFinancialInformation(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWithdrawalAccount(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "提现账号",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  SizedBox(width: Dimensions.padding8),
                  Icon(
                    size: Dimensions.iconSize32,
                    Icons.arrow_forward,
                  ),
                ],
              ),
              // TODO 加上默认提现账号信息
              // SizedBox(height: Dimensions.margin16),
              // Container(
              //   alignment: Alignment.centerLeft,
              //   child: Text(
              //     "户主：李华强\n"
              //     "账号：6217****2811\n"
              //     "银行：招商银行",
              //     style: TextStyle(
              //       color: Colors.grey,
              //       fontSize: Dimensions.fontSize32,
              //     ),
              //   ),
              // ),
            ],
          ),
          onPressed: () async {
            Get.to(WithdrawalAccountPage());
          },
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildAccountStatement(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "账户流水",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  SizedBox(width: Dimensions.padding8),
                  Icon(
                    size: Dimensions.iconSize32,
                    Icons.arrow_forward,
                  ),
                ],
              ),
            ],
          ),
          onPressed: () async {
            Get.to(TransactionPage());
          },
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildFinancialInformation(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "资金信息",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  // SizedBox(width: Dimensions.padding8),
                  // Icon(
                  //   size: Dimensions.iconSize32,
                  //   Icons.arrow_forward,
                  // ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Obx(
                () => Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "可提现余额（元）：${funds.value?.availableFunds}\n"
                    "冻结金额（元）：${funds.value?.frozenFunds}\n"
                    "待结算金额（元）：${funds.value?.pendingFunds}",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: Dimensions.fontSize32,
                    ),
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {},
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildName(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "店铺名称",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  // SizedBox(width: Dimensions.padding8),
                  // Icon(
                  //   size: Dimensions.iconSize32,
                  //   Icons.arrow_forward,
                  // ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${merchant.value?.name}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {},
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildId(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "店铺ID",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  // SizedBox(width: Dimensions.padding8),
                  // Icon(
                  //   size: Dimensions.iconSize32,
                  //   Icons.arrow_forward,
                  // ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${merchant.value?.id}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {},
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildPhoneNumber(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "联系电话",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  // SizedBox(width: Dimensions.padding8),
                  // Icon(
                  //   size: Dimensions.iconSize32,
                  //   Icons.arrow_forward,
                  // ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${merchant.value?.phone}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {
            // Get.to(ChangePhoneNumberPage());
          },
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildAddress(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "店铺地址",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  // SizedBox(width: Dimensions.padding8),
                  // Icon(
                  //   size: Dimensions.iconSize32,
                  //   Icons.arrow_forward,
                  // ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "地址：${merchant.value?.province}"
                  "${merchant.value?.city}"
                  "${merchant.value?.district}"
                  "${merchant.value?.detailedAddress}\n"
                  "经纬度：${merchant.value?.longitude}，${merchant.value?.latitude}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {},
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildBusinessStatus(BuildContext context) {
    return Column(
      children: [
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "营业状态",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: Dimensions.fontSize32,
                      ),
                    ),
                  ),
                  SizedBox(width: Dimensions.padding8),
                  Icon(
                    size: Dimensions.iconSize32,
                    Icons.arrow_forward,
                  ),
                ],
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${merchant.value?.isActive ?? false ? "营业中" : "已打烊"}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {},
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }
}
