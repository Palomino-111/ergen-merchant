import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zheergen_merchant_end/common/data/mapper/meal_delivery_order_mapper.dart';

/// 构造一条最小可解析的配送单 JSON（只保留 fromJson 必须字段）。
///
/// 注意：线上 meal_delivery_order 的 created_at / updated_at 是可为 NULL 的，
/// 这里默认就给 null，正好覆盖「历史数据时间字段为空」这条回归路径。
Map<String, dynamic> _baseRow({
  String id = 'delivery-order-1',
  String? recipeOrderId = 'recipe-order-1',
  String? mealId,
  Map<String, dynamic>? mealSnapshot,
  Map<String, dynamic>? meal,
}) {
  return <String, dynamic>{
    'id': id,
    'merchant_id': 'merchant-1',
    'recipe_order_id': recipeOrderId,
    'meal_id': mealId,
    'meal_snapshot': mealSnapshot ?? <String, dynamic>{},
    'recipient_name': '测试收货人',
    'phone': '13500000000',
    'province': '某省',
    'city': '某市',
    'district': '某区',
    'detailed_address': '某地址',
    'longitude': 113.0,
    'latitude': 22.5,
    'delivery_time': '2025-07-18T08:00:00+00:00',
    'delivered_at': null,
    'status': 'awaiting_preparation',
    'created_at': null,
    'updated_at': null,
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
  String name = '早餐',
  List<Map<String, dynamic>> dishSkus = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': null,
    'start_time': 28800000,
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

void main() {
  group('MealDeliveryOrderMapper.parseList', () {
    test('解析真实嵌套响应：meal / dish_sku 都挂到配送单上', () {
      final String raw = File(
        'test/fixtures/meal_delivery_order_nested.json',
      ).readAsStringSync();

      final orders = MealDeliveryOrderMapper.parseList(jsonDecode(raw));

      expect(orders.length, 2);
      final order = orders.first;
      expect(order.merchantId, '67320155-5301-4bd5-8765-946259723c07');
      expect(order.status, 'awaiting_preparation');
      // meal 关联
      expect(order.meal, isNotNull);
      expect(order.mealName, '晚餐');
      expect(order.meal!.startTime, 579600000);
      // dish_sku 关联（真实数据里两个菜品的 sort_order 都是 0，
      // 这里验证「按 sort_order + 响应顺序」的稳定排序不会把它们顺序打乱）
      expect(order.dishSkus.map((e) => e.name).toList(), <String>[
        '白灼西蓝花-300g',
        '白灼菜心-100g',
      ]);
      // 时间字段线上可能是 null，解析不能抛
      expect(order.createdAt, isNotNull);
    });

    test('created_at / updated_at 为 null 时不抛异常', () {
      final orders = MealDeliveryOrderMapper.parseList(<dynamic>[_baseRow()]);

      expect(orders.length, 1);
      expect(orders.first.createdAt, isNull);
      expect(orders.first.updatedAt, isNull);
      expect(orders.first.meal, isNull);
    });

    test('meal 关联缺失时用 meal_snapshot 兜底', () {
      final orders = MealDeliveryOrderMapper.parseList(<dynamic>[
        _baseRow(
          mealId: null,
          mealSnapshot: <String, dynamic>{
            'id': 'meal-1',
            'name': '午餐',
            'dish_skus': <Map<String, dynamic>>[
              _dishSkuJson(id: 'dish-sku-2', name: '牛奶-100g', sortOrder: 2),
              _dishSkuJson(id: 'dish-sku-1', name: '白灼菜心-100g', sortOrder: 1),
            ],
          },
        ),
      ]);

      final order = orders.first;
      expect(order.meal, isNull);
      expect(order.mealName, '午餐');
      // 快照里的菜品也要按 sort_order 排序
      expect(order.dishSkus.map((e) => e.name).toList(), <String>[
        '白灼菜心-100g',
        '牛奶-100g',
      ]);
    });

    test('meal 被 PostgREST 包成单元素数组时也能解析', () {
      final orders = MealDeliveryOrderMapper.parseList(<dynamic>[
        <String, dynamic>{
          ..._baseRow(mealId: 'meal-1'),
          'meal': <Map<String, dynamic>>[
            _mealJson(name: '晚餐', dishSkus: <Map<String, dynamic>>[
              _dishSkuJson(name: '白灼西蓝花-300g'),
            ]),
          ],
        },
      ]);

      expect(orders.single.meal, isNotNull);
      expect(orders.single.mealName, '晚餐');
      expect(orders.single.dishSkus.single.name, '白灼西蓝花-300g');
    });

    test('meal 是空数组时按无关联处理', () {
      final orders = MealDeliveryOrderMapper.parseList(<dynamic>[
        <String, dynamic>{
          ..._baseRow(),
          'meal': <Map<String, dynamic>>[],
        },
      ]);

      expect(orders.single.meal, isNull);
    });

    test('非 List / 空响应按空列表处理', () {
      expect(MealDeliveryOrderMapper.parseList(null), isEmpty);
      expect(MealDeliveryOrderMapper.parseList(<dynamic>[]), isEmpty);
      expect(MealDeliveryOrderMapper.parseList('oops'), isEmpty);
    });
  });

  test('groupByRecipeOrderId 按 recipe_order_id 分组', () {
    final orders = MealDeliveryOrderMapper.parseList(<dynamic>[
      _baseRow(id: 'a', recipeOrderId: 'order-1'),
      _baseRow(id: 'b', recipeOrderId: 'order-1'),
      _baseRow(id: 'c', recipeOrderId: 'order-2'),
    ]);

    final grouped = MealDeliveryOrderMapper.groupByRecipeOrderId(orders);

    expect(grouped.keys.toSet(), <String>{'order-1', 'order-2'});
    expect(grouped['order-1']!.map((e) => e.id).toList(), <String>['a', 'b']);
    expect(grouped['order-2']!.single.id, 'c');
  });
}
