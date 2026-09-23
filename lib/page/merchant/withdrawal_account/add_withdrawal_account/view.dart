import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../../common/dimensions.dart';
import '../../../../common/utility/common.dart';
import '../../../../common/widget/app_bar_scaffold.dart';
import '../../../../common/widget/bottom_bar_scaffold.dart';
import '../../../../common/widget/page_scaffold.dart';
import 'logic.dart';

class AddWithdrawalAccountPage extends StatelessWidget {
  AddWithdrawalAccountPage({Key? key}) : super(key: key);

  final logic = Get.put(AddWithdrawalAccountLogic());
  final state = Get.find<AddWithdrawalAccountLogic>().state;
  final merchant = MerchantController.to.merchant;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddWithdrawalAccountLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "添加提现账号",
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
                      // 银行名称
                      buildBankNameTitle(),
                      buildBankName(context),
                      // 银行卡账号
                      buildBankAccountNumberTitle(),
                      buildBankAccountNumber(context),
                      // 银行卡户主
                      buildBankAccountHolderTitle(),
                      buildBankAccountHolder(context),
                      // 是否为默认提现账户
                      buildIsDefaultTitle(),
                      buildIsDefault(context),
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

  Widget buildBankName(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(top: Dimensions.margin16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
        controller: state.bankNameController,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: "填写银行名称",
          contentPadding: EdgeInsets.all(Dimensions.padding16),
        ),
        onChanged: (s) => state.bankName = s,
      ),
    );
  }

  Widget buildBankNameTitle() {
    return Container(
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        "银行名称",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildBankAccountNumber(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(top: Dimensions.margin16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: "填写银行卡账号",
          contentPadding: EdgeInsets.all(Dimensions.padding16),
        ),
        onChanged: (s) => state.bankAccountNumber = s,
      ),
    );
  }

  Widget buildBankAccountNumberTitle() {
    return Container(
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        "银行卡账号",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildBankAccountHolder(BuildContext context) {
    return Container(
      height: Dimensions.button60,
      margin: EdgeInsets.only(top: Dimensions.margin16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: "填写银行卡户主",
          contentPadding: EdgeInsets.all(Dimensions.padding16),
        ),
        onChanged: (s) => state.bankAccountHolder = s,
      ),
    );
  }

  Widget buildBankAccountHolderTitle() {
    return Container(
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        "银行卡户主",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildIsDefault(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: Dimensions.button60,
            margin: EdgeInsets.only(top: Dimensions.margin16),
            alignment: Alignment.centerLeft,
            child: Text(
              "提现时会自动提现到默认提现账号中",
              style: TextStyle(
                fontSize: Dimensions.fontSize32,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        Obx(
          () => ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            child: BackdropFilter(
              filter: buildImageFilter(),
              child: CupertinoButton(
                minSize: Dimensions.button60,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                padding: EdgeInsets.zero,
                child: Transform.scale(
                  scale: 1.8,
                  child: Checkbox(
                    checkColor: Theme.of(context).colorScheme.onSurface,
                    activeColor: Colors.transparent,
                    side: const BorderSide(color: Colors.transparent),
                    fillColor: WidgetStateProperty.all(Colors.transparent),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    overlayColor:
                        WidgetStateProperty.all<Color?>(Colors.transparent),
                    value: state.isDefault.value,
                    onChanged: (bool? value) {
                      state.isDefault.value = value!;
                    },
                  ),
                ),
                onPressed: () async {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildIsDefaultTitle() {
    return Container(
      margin: EdgeInsets.only(
        top: Dimensions.margin16,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        "是否为默认提现账号",
        style: TextStyle(
          fontSize: Dimensions.fontSize32,
        ),
      ),
    );
  }

  Widget buildBottomBar(BuildContext context) {
    return BottomBarScaffold(
      child: CupertinoButton(
        minSize: Dimensions.button60,
        child: Text(
          "保存",
          style: TextStyle(
            fontSize: Dimensions.fontSize32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        onPressed: () async {
          await logic.addWithdrawalAccount(context);
        },
      ),
    );
  }
}
