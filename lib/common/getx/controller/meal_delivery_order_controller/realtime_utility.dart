import '../../../models/meal_delivery_order.dart';

/// 用「数据库表行」更新一个已经加载好的配送单对象。
///
/// 用在两条链路上，它们拿到的都是同一种东西——`meal_delivery_order` 这一张
/// 表的行，没有嵌套：
/// - Realtime 推送的 `payload.newRecord`
/// - 回到前台时按 id 批量重查的结果
///
/// **为什么不能直接 `MealDeliveryOrder.fromJson(row)` 替换掉旧对象：**
/// 表行里没有 meal / meal_dish / dish_sku 的嵌套——那是 PostgREST 的 join，
/// 不是表里的列。直接替换会把列表接口辛辛苦苦一次查回来的菜品列表清空，
/// 界面上会变成「菜品获取失败」。所以这里把嵌套字段从旧对象上搬回来。
///
/// [row] 里如果有脏数据导致解析失败（例如 `created_at` 不是时间串），
/// 退化成只更新状态相关的三个字段：一次解析失败不该让状态更新整体丢掉。
MealDeliveryOrder mergeDeliveryOrderRow(
  MealDeliveryOrder old,
  Map<String, dynamic> row,
) {
  try {
    final MealDeliveryOrder incoming = MealDeliveryOrder.fromJson(row);
    return incoming
      ..dishSkus = old.dishSkus
      ..meal = old.meal
      ..mealName = old.meal?.name ?? old.mealName;
  } catch (e, st) {
    print('mergeDeliveryOrderRow, parse fail, fallback to status only, $e, $st');
    return old.copyWith(
      status: row['status'] as String?,
      deliveredAt: parseDeliveryOrderTime(row['delivered_at']),
      updatedAt: parseDeliveryOrderTime(row['updated_at']),
    );
  }
}

/// 表行里的时间字段是 ISO8601 字符串；
/// 脏数据（null / 非法格式）返回 null 而不是抛异常，别让一个字段毁掉整次更新。
DateTime? parseDeliveryOrderTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
