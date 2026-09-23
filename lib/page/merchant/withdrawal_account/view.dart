import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import 'package:zheergen_merchant_end/page/merchant/withdrawal_account/edit_withdrawal_account/view.dart';
import '../../../common/dimensions.dart';
import '../../../common/widget/app_bar_scaffold.dart';
import '../../../common/widget/bottom_bar_scaffold.dart';
import '../../../common/widget/page_scaffold.dart';
import 'add_withdrawal_account/view.dart';
import 'logic.dart';

class WithdrawalAccountPage extends StatelessWidget {
  WithdrawalAccountPage({Key? key}) : super(key: key);

  final logic = Get.put(WithdrawalAccountLogic());
  final state = Get.find<WithdrawalAccountLogic>().state;
  final merchant = MerchantController.to.merchant;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WithdrawalAccountLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "提现账号",
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
                  child: Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TODO 加上默认提现账号的UI
                        ...List.generate(
                          MerchantController.to.withdrawalAccountList.length,
                          (index) {
                            return buildWithdrawalAccount(
                              context,
                              MerchantController
                                  .to.withdrawalAccountList[index],
                            );
                          },
                        ),
                        SizedBox(height: Dimensions.margin16),
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

  Widget buildWithdrawalAccount(
    BuildContext context,
    WithdrawalAccount withdrawalAccount,
  ) {
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
                      "${withdrawalAccount.bankName}",
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
                  "账号：${withdrawalAccount.bankAccountNumber}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
              SizedBox(height: Dimensions.margin16),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  "户主：${withdrawalAccount.bankAccountHolder}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {
            Get.to(EditWithdrawalAccountPage(withdrawalAccount));
          },
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: CupertinoButton(
        minSize: Dimensions.button60,
        child: Text(
          "添加",
          style: TextStyle(
            fontSize: Dimensions.fontSize32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onPressed: () async {
          await Get.to(AddWithdrawalAccountPage());
        },
      ),
    );
  }
}
