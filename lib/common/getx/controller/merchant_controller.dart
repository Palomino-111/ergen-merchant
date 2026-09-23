import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zheergen_merchant_end/common/models/withdrawal_account.dart';
import '../../../main.dart';
import '../../exception/showable_exception.dart';
import '../../hive_names.dart';
import '../../models/funds.dart';
import '../../models/merchant.dart';
import 'account_controller.dart';

class MerchantController extends GetxController {
  static MerchantController get to => Get.find();
  Rxn<Merchant> merchant = Rxn();
  RxList<WithdrawalAccount> withdrawalAccountList = RxList();
  Rxn<Funds> funds = Rxn();

  /**
   * 账号授权状态改变，商家信息也要跟着变化
   */
  Future<void> onAuthStateChange(
    AuthState authState,
  ) async {
    // 商家信息更新
    if (AccountController.to.user.value == null) {
      // 退出登录或者其它导致用户账号无法使用的情况，需要清除商家信息
      clear();
    } else {
      if (authState.event == AuthChangeEvent.signedIn) {
        // 登录时需要强制从服务器获取最新的商家信息
        await fetchMerchant();
      } else {
        // 其它非登录情况优先从缓存中获取商家信息
        if (merchant.value == null) {
          // 优先从缓存获取商家信息，没有的情况下再去服务器获取
          Map? cachedMerchantJson =
              Hive.box(HiveNames.settings).get('merchant');
          if (cachedMerchantJson != null) {
            merchant.value = Merchant.fromJson(cachedMerchantJson);
          } else {
            await fetchMerchant();
          }
        }
      }
    }
  }

  /**
   * 获取店铺信息
   */
  Future<void> fetchMerchant() async {
    try {
      final userId = AccountController.to.user.value?.id;
      if (userId == null) throw ShowableException('用户未登录');

      final response = await supabase
          .from('merchant')
          .select()
          .eq('user_id', AccountController.to.user.value!.id)
          .single();
      final merchant = Merchant.fromJson(response);
      this.merchant.value = merchant;
      // 更好的方式是写Hive Adapter（可以用Hive提供的工具自动生成），这里为了方便，先直接存JSON
      // 缓存merchant
      Hive.box(HiveNames.settings).put('merchant', merchant.toJson());
    } catch (e, st) {
      print("fetchMerchant, fail, $e, $st");
      throw ShowableException('获取店铺信息失败，未知错误！');
    }
  }

  /**
   * 获取提现账号列表
   */
  Future<void> fetchWithdrawalAccountList() async {
    try {
      final merchantId = merchant.value?.id;
      if (merchantId == null) throw ShowableException('店铺ID不存在');

      final response = await supabase
          .from('merchant_withdrawal_account')
          .select()
          .eq('merchant_id', merchantId)
          .order('updated_at', ascending: false);
      final result = response.map((e) => WithdrawalAccount.fromJson(e));
      withdrawalAccountList.assignAll(result);
    } catch (e, st) {
      print("fetchWithdrawalAccountList, fail, $e, $st");
      throw ShowableException('获取提现账号失败，未知错误！');
    }
  }

  /**
   * 添加提现账号
   */
  Future<void> addWithdrawalAccount(WithdrawalAccount withdrawalAccount) async {
    final merchantId = merchant.value?.id;
    if (merchantId == null) throw ShowableException('店铺ID不存在');
    try {
      await supabase
          .from('merchant_withdrawal_account')
          .insert(withdrawalAccount.toJson());
      // TODO 没必要手动拉取，只要监听数据库改变就行
      await fetchWithdrawalAccountList();
    } catch (e, st) {
      print("addWithdrawalAccount, fail, $e, $st");
      throw ShowableException('添加失败，未知错误！');
    }
  }

  Future<void> updateWithdrawalAccount(
    WithdrawalAccount withdrawalAccount,
  ) async {
    final withdrawalAccountId = withdrawalAccount.id;
    if (withdrawalAccountId == null) throw ShowableException('提现账号ID不存在');

    if (withdrawalAccount.isDefault) {
      await _cancelOldDefault(withdrawalAccount.merchantId);
    }

    try {
      await supabase
          .from('merchant_withdrawal_account')
          .update(withdrawalAccount.toJson())
          .eq("merchant_id", withdrawalAccount.merchantId)
          .eq("id", withdrawalAccountId);
      // TODO 没必要手动拉取，只要监听数据库改变就行
      await fetchWithdrawalAccountList();
    } catch (e, st) {
      print("updateWithdrawalAccount, fail, $e, $st");
      throw ShowableException('更新失败，未知错误！');
    }
  }

  /**
   * 用户信息没有（一般是登出状态）时，清除内存和缓存的商家信息
   */
  void clear() {
    merchant.value = null;
    Hive.box(HiveNames.settings).put('merchant', null);
  }

  /**
   * 取消旧的默认提现账号
   */
  Future<void> _cancelOldDefault(String merchantId) async {
    await supabase
        .from('merchant_withdrawal_account')
        .update({'is_default': false})
        .eq('merchant_id', merchantId)
        .eq('is_default', true);
  }

  Future<void> deleteWithdrawalAccount(
    WithdrawalAccount withdrawalAccount,
  ) async {
    final withdrawalAccountId = withdrawalAccount.id;
    if (withdrawalAccountId == null) throw ShowableException('提现账号ID不存在');
    try {
      await supabase
          .from('merchant_withdrawal_account')
          .delete()
          .eq("merchant_id", withdrawalAccount.merchantId)
          .eq("id", withdrawalAccountId);
      // TODO 没必要手动拉取，只要监听数据库改变就行
      await fetchWithdrawalAccountList();
    } catch (e, st) {
      print("deleteWithdrawalAccount, fail, $e, $st");
      throw ShowableException('😂 删除失败，未知错误！');
    }
  }

  /**
   * 获取商家资金信息
   */
  Future<void> fetchFundsInformation() async {
    try {
      final merchantId = merchant.value?.id;
      if (merchantId == null) throw ShowableException('店铺ID不存在');
      final response = await supabase
          .from('merchant_funds')
          .select()
          .eq('merchant_id', merchantId)
          .single();
      funds.value = Funds.fromJson(response);
    } catch (e, st) {
      print("fetchFundsInformation, fail, $e, $st");
      throw ShowableException('获取资金信息失败，未知错误！');
    }
  }
}
