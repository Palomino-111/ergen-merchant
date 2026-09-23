import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import 'package:zheergen_merchant_end/page/merchant/withdrawal_account/edit_withdrawal_account/state.dart';
import '../../../../common/dimensions.dart';
import '../../../../common/utility/common.dart';
import '../../../../common/widget/app_bar_scaffold.dart';
import '../../../../common/widget/dialog/text_dialog.dart';
import '../../../../common/widget/page_scaffold.dart';
import 'logic.dart';

class EditWithdrawalAccountPage extends StatelessWidget {
  final EditWithdrawalAccountLogic logic;
  final EditWithdrawalAccountState state;
  final merchant = MerchantController.to.merchant;

  EditWithdrawalAccountPage(WithdrawalAccount withdrawalAccount, {Key? key})
      : logic = Get.put(EditWithdrawalAccountLogic(withdrawalAccount)),
        state = Get.find<EditWithdrawalAccountLogic>().state,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditWithdrawalAccountLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          appBar: AppBarScaffold(
            titleString: "编辑提现账号",
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
        controller: state.bankAccountNumberController,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: "填写银行卡账号",
          contentPadding: EdgeInsets.all(Dimensions.padding16),
        ),
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
        controller: state.bankAccountHolderController,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: "填写银行卡户主",
          contentPadding: EdgeInsets.all(Dimensions.padding16),
        ),
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
    return Row(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: Dimensions.margin16,
              top: Dimensions.margin16,
              bottom: Dimensions.margin16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            ),
            clipBehavior: Clip.hardEdge,
            child: BackdropFilter(
              filter: buildImageFilter(),
              child: CupertinoButton(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                minSize: Dimensions.button60,
                padding: EdgeInsets.all(Dimensions.padding16),
                child: Text(
                  "删除",
                  style: TextStyle(
                    fontSize: Dimensions.fontSize32,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onPressed: () async {
                  showDeleteAlertDialog(context);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.all(
              Dimensions.margin16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
            ),
            clipBehavior: Clip.hardEdge,
            child: BackdropFilter(
              filter: buildImageFilter(),
              child: CupertinoButton(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                minSize: Dimensions.button60,
                padding: EdgeInsets.all(Dimensions.padding16),
                child: Text(
                  "更新",
                  style: TextStyle(
                    fontSize: Dimensions.fontSize32,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onPressed: () async {
                  await logic.updateWithdrawalAccount(context);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showDeleteAlertDialog(BuildContext context) async {
    showDialog<String>(
      context: context,
      builder: (context) => TextDialog(
        title: "确认删除？",
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
        await logic.deleteWithdrawalAccount(context);
      }
    });
  }
}
