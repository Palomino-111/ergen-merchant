import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/data/mapper/meal_delivery_order_mapper.dart';
import 'package:zheergen_merchant_end/common/data/repository/meal_delivery_order_repository.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/awaiting_preparation_meal_delivery_order_controller.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/realtime_utility.dart';
import 'package:zheergen_merchant_end/common/models/meal_delivery_order.dart';

/// 构造一条最小可解析的配送单表行。
///
/// 和 mapper 测试保持同一份形状；这里额外关注的是「表行**没有** meal /
/// meal_dish / dish_sku 嵌套」这件事——Realtime 推来的就是这种行。
Map<String, dynamic> _row({
  String id = 'delivery-order-1',
  String status = 'awaiting_preparation',
  String? deliveredAt,
  String? updatedAt,
  Map<String, dynamic>? meal,
}) {
  return <String, dynamic>{
    'id': id,
    'merchant_id': 'merchant-1',
    'recipe_order_id': 'recipe-order-1',
    'meal_id': 'meal-1',
    'meal_snapshot': <String, dynamic>{},
    'recipient_name': '测试收货人',
    'phone': '13500000000',
    'province': '某省',
    'city': '某市',
    'district': '某区',
    'detailed_address': '某地址',
    'longitude': 113.0,
    'latitude': 22.5,
    'delivery_time': '2025-07-18T08:00:00+00:00',
    'delivered_at': deliveredAt,
    'status': status,
    'created_at': null,
    'updated_at': updatedAt,
    if (meal != null) 'meal': meal,
  };
}

Map<String, dynamic> _dishSkuJson({
  String id = 'dish-sku-1',
  String name = '白灼菜心-100g',
  int sortOrder = 0,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'sku_code': 'SKU-100',
    'price': 16.0,
    'cost_price': null,
    'market_price': null,
    'stock': 100,
    'sales_volume': 0,
    'is_available': true,
    'sort_order': sortOrder,
    'created_at': null,
    'updated_at': null,
  };
}

Map<String, dynamic> _mealJson({
  String id = 'meal-1',
  String name = '晚餐',
  List<Map<String, dynamic>> dishSkus = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': null,
    'start_time': 579600000,
    'recipe_sku_id': 'recipe-sku-1',
    'created_at': '2025-06-07T22:43:56+00:00',
    'updated_at': '2025-06-07T22:43:56+00:00',
    'meal_dishes': dishSkus
        .map((dishSku) => <String, dynamic>{
              'meal_id': id,
              'dish_sku_id': dishSku['id'],
              'sort_order': 1,
              'dish_sku': dishSku,
            })
        .toList(),
  };
}

/// 列表接口查回来的那种「带嵌套」的配送单
MealDeliveryOrder _orderWithNested({
  String id = 'delivery-order-1',
  String status = 'awaiting_preparation',
}) {
  return MealDeliveryOrderMapper.parseList(<dynamic>[
    _row(
      id: id,
      status: status,
      meal: _mealJson(dishSkus: <Map<String, dynamic>>[
        _dishSkuJson(id: 'dish-sku-1', name: '白灼菜心-100g', sortOrder: 0),
        _dishSkuJson(id: 'dish-sku-2', name: '牛奶-100g', sortOrder: 1),
      ]),
    ),
  ]).single;
}

/// 只占住 GetX 的注册位：这些测试只关心列表和角标怎么变，不碰网络
class _UnusedRepository implements MealDeliveryOrderRepository {
  @override
  Future<List<MealDeliveryOrder>> fetchByMerchant({
    required String merchantId,
    String? status,
    required int page,
    int pageSize = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> countByMerchant({
    required String merchantId,
    String? status,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<MealDeliveryOrder>> getByRecipeOrderId(
    String recipeOrderId, {
    required String merchantId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Map<String, List<MealDeliveryOrder>>> getByRecipeOrderIds(
    List<String> recipeOrderIds, {
    required String merchantId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<MealDeliveryOrder>> fetchByIds(
    List<String> ids, {
    required String merchantId,
  }) =>
      throw UnimplementedError();

  @override
  void clearCache() => throw UnimplementedError();

  @override
  void clearCacheFor(String recipeOrderId) => throw UnimplementedError();

  @override
  void clearCacheForAll(Iterable<String> recipeOrderIds) =>
      throw UnimplementedError();
}

void main() {
  group('mergeDeliveryOrderRow', () {
    test('用表行更新状态后，meal / dishSkus 嵌套不能被冲掉', () {
      final MealDeliveryOrder old = _orderWithNested();
      expect(old.meal, isNotNull);
      expect(old.dishSkus.length, 2);

      // Realtime / 按 id 重查拿到的就是这种行：只有标量字段，没有嵌套
      final MealDeliveryOrder merged = mergeDeliveryOrderRow(
        old,
        _row(status: 'delivering', updatedAt: '2025-07-18T09:00:00+00:00'),
      );

      expect(merged.status, 'delivering');
      expect(merged.updatedAt, DateTime.parse('2025-07-18T09:00:00+00:00'));
      // 关键断言：嵌套字段是从旧对象上搬过来的
      expect(merged.meal, isNotNull);
      expect(merged.mealName, '晚餐');
      expect(merged.dishSkus.map((e) => e.name).toList(), <String>[
        '白灼菜心-100g',
        '牛奶-100g',
      ]);
    });

    test('行里有脏数据解析失败时，退化成只更新状态，不影响嵌套', () {
      final MealDeliveryOrder old = _orderWithNested();

      // 少了 recipient_name / phone / delivery_time 等必填字段，
      // fromJson 会抛异常，必须走兜底而不是让整次更新丢掉
      final MealDeliveryOrder merged = mergeDeliveryOrderRow(old, <String, dynamic>{
        'id': 'delivery-order-1',
        'status': 'delivered',
        'delivered_at': '2025-07-18T10:00:00+00:00',
      });

      expect(merged.status, 'delivered');
      expect(merged.deliveredAt, DateTime.parse('2025-07-18T10:00:00+00:00'));
      expect(merged.meal, isNotNull);
      expect(merged.dishSkus.length, 2);
      // 兜底路径碰不到的字段保持原样
      expect(merged.recipientName, old.recipientName);
    });

    test('时间字段是脏数据时按 null 处理，不抛异常', () {
      expect(parseDeliveryOrderTime(null), isNull);
      expect(parseDeliveryOrderTime('不是时间'), isNull);
      expect(
        parseDeliveryOrderTime('2025-07-18T10:00:00+00:00'),
        DateTime.parse('2025-07-18T10:00:00+00:00'),
      );
    });
  });

  group('AwaitingPreparationMealDeliveryOrderController', () {
    late AwaitingPreparationMealDeliveryOrderController controller;

    setUp(() {
      Get.testMode = true;
      Get.put<MealDeliveryOrderRepository>(_UnusedRepository());
      controller = Get.put(AwaitingPreparationMealDeliveryOrderController());
    });

    tearDown(Get.reset);

    /// 造出「待制作列表里有 n 条，角标也是 n」这个初始状态
    void seed(List<String> ids) {
      controller.awaitingPreparationMealDeliveryOrders.assignAll(
        ids
            .map((id) => _orderWithNested(
                  id: id,
                  status: AwaitingPreparationMealDeliveryOrderController
                      .awaitingPreparationStatus,
                ))
            .toList(),
      );
      controller.count.value = ids.length;
    }

    test('状态不再是待制作时立刻移除，并同步角标', () {
      seed(<String>['a', 'b']);

      controller.applyRealtimeUpdate(_row(id: 'a', status: 'delivering'));

      expect(
        controller.awaitingPreparationMealDeliveryOrders.map((e) => e.id),
        <String>['b'],
      );
      expect(controller.count.value, 1);
    });

    test('同一条状态变化重复到达时，角标不会被重复扣减', () {
      seed(<String>['a', 'b']);

      controller.applyRealtimeUpdate(_row(id: 'a', status: 'delivering'));
      // Realtime 推送和「回前台重查」可能都送到同一条，必须幂等
      controller.applyRealtimeUpdate(_row(id: 'a', status: 'delivering'));

      expect(controller.count.value, 1);
      expect(controller.awaitingPreparationMealDeliveryOrders.length, 1);
    });

    test('状态仍是待制作时原地更新，不移除也不动角标', () {
      seed(<String>['a']);

      controller.applyRealtimeUpdate(
        _row(id: 'a', status: 'awaiting_preparation', updatedAt: '2025-07-18T09:00:00+00:00'),
      );

      expect(controller.awaitingPreparationMealDeliveryOrders.length, 1);
      expect(controller.count.value, 1);
      expect(
        controller.awaitingPreparationMealDeliveryOrders.single.updatedAt,
        DateTime.parse('2025-07-18T09:00:00+00:00'),
      );
    });

    test('不在待制作列表里的单不会被插进来', () {
      seed(<String>['a']);

      controller.applyRealtimeUpdate(
        _row(id: '别的单', status: 'awaiting_preparation'),
      );

      expect(
        controller.awaitingPreparationMealDeliveryOrders.map((e) => e.id),
        <String>['a'],
      );
      expect(controller.count.value, 1);
    });

    test('派单的乐观更新与随后的 Realtime 推送共用一条路径，角标只扣一次', () {
      seed(<String>['a', 'b']);

      // 1. 派单成功，本地先改
      controller.applyDispatched('a', 'awaiting_delivery');
      expect(controller.count.value, 1);

      // 2. 服务端的 Realtime 事件随后到达同一条
      controller.applyRealtimeUpdate(_row(id: 'a', status: 'awaiting_delivery'));

      expect(controller.count.value, 1);
      expect(
        controller.awaitingPreparationMealDeliveryOrders.map((e) => e.id),
        <String>['b'],
      );
    });

    test('id 为空的行直接忽略', () {
      seed(<String>['a']);

      controller.applyRealtimeUpdate(<String, dynamic>{'status': 'delivering'});

      expect(controller.awaitingPreparationMealDeliveryOrders.length, 1);
      expect(controller.count.value, 1);
    });
  });
}
