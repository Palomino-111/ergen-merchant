import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum DeliveryStatus {
  // 待制作
  awaitingPreparation("awaiting_preparation"),
  // 制作中
  preparing("preparing"),
  // 待配送
  awaitingDelivery("awaiting_delivery"),
  // 配送中
  delivering("delivering"),
  // 已送达
  delivered("delivered"),
  // 已收货
  received("received"),
  // 已取消
  cancelled("cancelled");

  final String key;

  const DeliveryStatus(this.key);

  static DeliveryStatus? fromKey(String? key) {
    if (key == null) return null;
    try {
      return DeliveryStatus.values.firstWhere((status) => status.key == key);
    } catch (e, st) {
      print("DeliveryStatus.fromKey, $e, $st");
    }
    return null;
  }
}

extension DeliveryStatusLocalization on DeliveryStatus {
  String? localized(BuildContext context) {
    switch (this) {
      case DeliveryStatus.awaitingPreparation:
        return AppLocalizations.of(context)?.awaitingPreparation;
      case DeliveryStatus.preparing:
        return AppLocalizations.of(context)?.preparing;
      case DeliveryStatus.awaitingDelivery:
        return AppLocalizations.of(context)?.awaitingDelivery;
      case DeliveryStatus.delivering:
        return AppLocalizations.of(context)?.delivering;
      case DeliveryStatus.delivered:
        return AppLocalizations.of(context)?.delivered;
      case DeliveryStatus.received:
        return AppLocalizations.of(context)?.received;
      case DeliveryStatus.cancelled:
        return AppLocalizations.of(context)?.cancelled;
    }
  }
}
