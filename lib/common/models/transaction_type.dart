import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum TransactionType {
  // 配送订单结算
  mealDeliveryOrderSettle("meal_delivery_order_settle"),
  // 提现
  withdraw("withdraw"),
  // 配送订单退款
  mealDeliveryOrderRefund("meal_delivery_order_refund"),
  // 平台佣金
  platformFee("platform_fee"),
  // 人工调整
  adjustment("adjustment");

  final String key;

  const TransactionType(this.key);

  static TransactionType? fromKey(String? key) {
    if (key == null) return null;
    try {
      return TransactionType.values.firstWhere((status) => status.key == key);
    } catch (e) {
      print("TransactionType.fromKey, $e");
    }
    return null;
  }
}

// 扩展枚举的本地化
extension GenderLocalization on TransactionType {
  String? localized(BuildContext context) {
    switch (this) {
      case TransactionType.mealDeliveryOrderSettle:
        return AppLocalizations.of(context)?.mealDeliveryOrderSettle;
      case TransactionType.withdraw:
        return AppLocalizations.of(context)?.withdraw;
      case TransactionType.mealDeliveryOrderRefund:
        return AppLocalizations.of(context)?.mealDeliveryOrderRefund;
      case TransactionType.platformFee:
        return AppLocalizations.of(context)?.platformFee;
      case TransactionType.adjustment:
        return AppLocalizations.of(context)?.adjustment;
    }
  }
}
