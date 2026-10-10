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

/// 商家端「订单」页的分组（= 一个 tab）。
///
/// **为什么不一个 status 一个 tab**（2026-10 全库真实数据）：
/// - `preparing` / `received` 一条数据都没有、也找不到写入方，
///   给它们开 tab 只会得到永远空白的页面；
/// - status 描述的是「配送执行到哪一步」，而商家想的是「这单要不要我动手」：
///   待制作（要出餐、要派单）、在途（等骑手取餐 / 骑手在路上）、
///   已结束（对账、查历史、复盘取消）。
///
/// 分组是**唯一事实来源**：status 集合、排序方向、要不要角标、tab 文案、
/// 空状态文案都从这里读。view / controller 不要再各写一份 if，
/// 否则以后加一个状态就会有人漏改，表现为「订单在某个 tab 里凭空消失」。
///
/// **枚举声明顺序 = tab 展示顺序。**
enum DeliveryStatusGroup {
  /// 待制作：需要商家出餐 → 派单
  toPrepare(
    label: '待制作',
    emptyText: '暂时没有要做的单！😝',
    ascending: true,
    countBadge: true,
    showItemStatus: false,
    fromTodayOnly: true,
  ),

  /// 在途：已经派过单，等骑手取餐 / 骑手在路上
  inTransit(
    label: '在途',
    emptyText: '没有在途的订单！😝',
    ascending: true,
    countBadge: false,
    showItemStatus: false,
    fromTodayOnly: true,
  ),

  /// 已结束：已送达 / 已收货 / 已取消
  finished(
    label: '已结束',
    emptyText: '还没有已结束的订单！😝',
    ascending: false,
    countBadge: false,
    showItemStatus: true,
    // 历史单要能一直往前翻，不能只看今天
    fromTodayOnly: false,
  ),

  /// 全部：不过滤状态，查单/兜底入口
  ///
  /// 刻意排在最后：真实数据里它和「待制作」高度重合（全库 5556 条里
  /// 5511 条是待制作），日常出餐用不到，只有「按 id 找某一单」
  /// 「看看有没有漏网状态」时才点。
  ///
  /// statuses 为空 = 不做状态过滤（数据层就是这么解释空集合的）。
  all(
    label: '全部',
    emptyText: '还没有订单！😝',
    ascending: false,
    countBadge: false,
    showItemStatus: true,
    fromTodayOnly: false,
  );

  const DeliveryStatusGroup({
    required this.label,
    required this.emptyText,
    required this.ascending,
    required this.countBadge,
    required this.showItemStatus,
    required this.fromTodayOnly,
  });

  /// tab 文案（TODO 目前和项目里其它 tab 文案一样是硬编码中文，
  /// 等统一做 l10n 时和状态文案一起搬进 arb）
  final String label;

  /// 列表为空时的文案
  final String emptyText;

  /// 组内是否按「预计送达时间」升序。
  ///
  /// 未结束的组必须升序：商家要的是「接下来该做哪一单」，
  /// 而降序会把最远未来的单排在最前面（真实数据里就出现过
  /// 「今天要做的单在第 11 页」）。
  final bool ascending;

  /// 是否维护并展示角标（会多一次 count 请求）
  final bool countBadge;

  /// item 卡片上是否展示「配送状态」行。
  ///
  /// 同一组内状态恒定，展示它是纯噪音；只有「已结束」组里混着
  /// 已送达 / 已收货 / 已取消三种状态，才需要区分。
  final bool showItemStatus;

  /// 是否只展示「今天及以后」要送的单（下界过滤）。
  ///
  /// 为什么必须有它：待制作组里有大量**早就过了预计送达时间**却一直没派单的
  /// 历史单（2026-10 全库统计：5511 条待制作里 4349 条已过期，最早到 2025-07）。
  /// 组内又要按送达时间**升序**排（好让「接下来该做哪一单」在最上面），
  /// 两者一叠加，最前面出现的就会是那批一年前的僵尸单——比不排序还糟。
  ///
  /// 所以未结束的两个组都从「今天 00:00」开始看：当天已经过点的单仍然留着
  /// （商家晚做、晚派单是常态，不能一到点就看不见），昨天的就不再占用屏幕。
  ///
  /// 注意这只定**下界**；「最多往后看几天」（今天+明天 / 未来 N 天）是另一个
  /// 决策，还没定，见 documents/待办.md。
  final bool fromTodayOnly;

  /// 本组要用的「起始送达时间」筛选值；不需要筛选（已结束）时返回 null。
  ///
  /// 返回的是**手机的本地时间**（当天 00:00），序列化时再转 UTC——
  /// 直接用 UTC 切天会让国内商家在早上 8 点前看成「昨天」。
  DateTime? get deliveryTimeFrom {
    if (!fromTodayOnly) {
      return null;
    }
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 本组包含的 status（对应 [DeliveryStatus.key]）
  List<String> get statuses {
    switch (this) {
      case DeliveryStatusGroup.toPrepare:
        return <String>[
          DeliveryStatus.awaitingPreparation.key,
          // 防御性保留：线上目前没有这个状态的数据，也没有写入方，
          // 但万一后端/骑手端将来开始写，单子不能凭空从列表里消失
          DeliveryStatus.preparing.key,
        ];
      case DeliveryStatusGroup.inTransit:
        return <String>[
          DeliveryStatus.awaitingDelivery.key,
          DeliveryStatus.delivering.key,
        ];
      case DeliveryStatusGroup.finished:
        return <String>[
          DeliveryStatus.delivered.key,
          // 同上，防御性保留
          DeliveryStatus.received.key,
          DeliveryStatus.cancelled.key,
        ];
      case DeliveryStatusGroup.all:
        // 空集合 = 不加 status 条件（数据层把空集合当成「不过滤」）
        return <String>[];
    }
  }

  /// [status] 是否属于本组。
  ///
  /// 「全部」这种 statuses 为空的分组返回 **true**：它的语义是「什么状态都收」。
  /// 这里要是返回 false，Realtime 一推状态变化，列表就会把这条单整个删掉
  /// （见 MealDeliveryOrderListController.applyRealtimeUpdate）。
  bool containsStatus(String? status) {
    if (statuses.isEmpty) {
      return true;
    }
    return status != null && statuses.contains(status);
  }
}
