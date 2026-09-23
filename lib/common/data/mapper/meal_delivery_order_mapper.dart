import '../../models/dish_sku.dart';
import '../../models/meal.dart';
import '../../models/meal_delivery_order.dart';

/// 配送单嵌套查询串：meal_delivery_order → meal → meal_dish → dish_sku
///
/// 单查 / 批量 in 查询 / 分页列表共用同一份，避免多处漂移。
/// 不写 `!` INNER JOIN 语法：PostgREST 按外键自动做 LEFT JOIN 更稳定，
/// meal 被删掉时配送单仍然能查出来（退化成 null，再由快照兜底）。
const String mealDeliveryOrderSelect = '''
      *,
      meal(*,
        meal_dishes:meal_dish(*,
          dish_sku(*)
        )
      )
    ''';

/// 配送单 JSON 解析器（含 meal / dish_sku 嵌套）
///
/// 对应消费端的 ModelJsonParser.parseMealDeliveryOrderWithRelations，
/// 商家端这里只保留配送单这一条链路。
abstract final class MealDeliveryOrderMapper {
  /// 解析列表响应；[response] 不是 List 时按空列表处理。
  static List<MealDeliveryOrder> parseList(dynamic response) {
    if (response is! List) {
      return <MealDeliveryOrder>[];
    }
    return response
        .whereType<Map>()
        .map((row) => parseRow(_toDynamicMap(row)))
        .toList();
  }

  /// 解析一张配送单及其关联的 meal / dish_sku。
  ///
  /// [row] 里的 meal 关联可能是三种形态：对象 / 单元素数组 / null
  /// （PostgREST 在部分配置下会把嵌套资源包成数组），这里统一归一化；
  /// meal 取不到（FK 为空或餐已被删除）时只填快照里的字段兜底。
  static MealDeliveryOrder parseRow(Map<String, dynamic> row) {
    final order = MealDeliveryOrder.fromJson(row);

    dynamic mealJson = row['meal'];
    if (mealJson is List) {
      mealJson = mealJson.isEmpty ? null : mealJson.first;
    }
    if (mealJson is! Map) {
      return _fillFromSnapshot(order);
    }

    final Map<String, dynamic> mealMap = _toDynamicMap(mealJson);
    final List<DishSku> dishSkus = _parseDishSkus(mealMap['meal_dishes']);
    final Meal meal = Meal.fromJson(mealMap)..dishSkus = dishSkus;

    order.meal = meal;
    order.dishSkus = dishSkus;
    order.mealName = meal.name;
    return order;
  }

  /// 按 recipe_order_id 分组，供批量查询使用。
  ///
  /// recipe_order_id 为空的配送单会被跳过（与消费端「空即无数据」语义一致）。
  static Map<String, List<MealDeliveryOrder>> groupByRecipeOrderId(
    Iterable<MealDeliveryOrder> orders,
  ) {
    final Map<String, List<MealDeliveryOrder>> result = {};
    for (final MealDeliveryOrder order in orders) {
      final String key = order.recipeOrderId ?? '';
      if (key.isEmpty) {
        continue;
      }
      result.putIfAbsent(key, () => <MealDeliveryOrder>[]).add(order);
    }
    return result;
  }

  /// 解析 meal_dishes 里的 dish_sku，按 sort_order 升序。
  ///
  /// Dart 的 List.sort 不是稳定排序，而真实数据里多个菜品的 sort_order
  /// 往往是相同的（都是 0/1），所以这里用「响应顺序」做次级比较，
  /// 保证同样 sort_order 时顺序不会随机跳动。
  static List<DishSku> _parseDishSkus(dynamic mealDishes) {
    if (mealDishes is! List) {
      return <DishSku>[];
    }
    final List<MapEntry<int, DishSku>> indexed = <MapEntry<int, DishSku>>[];
    int index = 0;
    for (final item in mealDishes) {
      if (item is! Map) {
        continue;
      }
      final dynamic dishSkuJson = item['dish_sku'];
      if (dishSkuJson is! Map) {
        continue;
      }
      indexed.add(
        MapEntry(
          index++,
          DishSku.fromJson(_toDynamicMap(dishSkuJson)),
        ),
      );
    }
    indexed.sort((a, b) {
      final int bySortOrder = a.value.sortOrder.compareTo(b.value.sortOrder);
      return bySortOrder != 0 ? bySortOrder : a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList();
  }

  /// meal 关联取不到时，用 meal_snapshot 兜底。
  ///
  /// 快照里的 dish_skus 由下单链路写入，脏数据直接跳过，不影响整单展示；
  /// 此时不构造 Meal 对象（只有快照，信息不完整），由调用方决定是否再查一次。
  static MealDeliveryOrder _fillFromSnapshot(MealDeliveryOrder order) {
    final Map<String, dynamic> snapshot = order.mealSnapshot;
    final dynamic dishSkusRaw = snapshot['dish_skus'];
    final List<DishSku> dishSkus = <DishSku>[];
    if (dishSkusRaw is List) {
      for (final item in dishSkusRaw) {
        if (item is! Map) {
          continue;
        }
        try {
          dishSkus.add(DishSku.fromJson(_toDynamicMap(item)));
        } catch (_) {
          // 快照里的脏数据跳过
        }
      }
      dishSkus.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    order.dishSkus = dishSkus;
    order.mealName = snapshot['name']?.toString() ?? '';
    return order;
  }

  static Map<String, dynamic> _toDynamicMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}
