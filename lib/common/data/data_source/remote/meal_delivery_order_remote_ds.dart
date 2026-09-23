import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../models/meal_delivery_order.dart';
import '../../../utility/network.dart';
import '../../mapper/meal_delivery_order_mapper.dart';

/// 配送单远程数据源（PostgREST 直查，不走 Edge Function）
///
/// 与消费端的同名接口唯一的区别：**所有查询都必须带 merchant_id 条件**。
/// 消费端的 getMealDeliveryOrders 只按 recipe_order_id 过滤，安全是因为
/// 调用方只会传自己的订单 id + RLS 兜底；商家端要「查我店里的配送单」，
/// 归属过滤必须写在数据层，不能指望每个调用方都记得传自己的 merchantId。
///
/// 另外所有请求都套了 [withNetworkTimeout]：Supabase 域名在国内经常连不上，
/// 没有超时的话请求会一直挂着，界面表现就是「一直在加载」且不报错。
abstract class MealDeliveryOrderRemoteDS {
  /// 分页查我店里的配送单，按预定送达时间倒序（新单在前）。
  ///
  /// [status] 为 null 表示不过滤状态（全部）；一次查询就带出
  /// meal / meal_dish / dish_sku 嵌套，避免每个 item 再查一次餐品（N+1）。
  Future<List<MealDeliveryOrder>> fetchListByMerchant({
    required String merchantId,
    String? status,
    required int page,
    int pageSize = 20,
  });

  /// 我店里的配送单总数（[status] 为 null 表示不过滤状态）。
  ///
  /// 用 estimated count：只要数量级正确即可，避免 exact 在大表上的全表扫描。
  Future<int> countByMerchant({
    required String merchantId,
    String? status,
  });

  /// 查某个食谱订单下我店里的配送单（带 meal/dish_sku 嵌套）。
  Future<List<MealDeliveryOrder>> fetchByRecipeOrderId(
    String recipeOrderId, {
    required String merchantId,
  });

  /// 批量查多个食谱订单的配送单（一次 in 查询，避免逐个订单查造成 N+1）。
  ///
  /// 返回 recipe_order_id -> 配送单列表；查不到的订单不会出现在 Map 里。
  Future<Map<String, List<MealDeliveryOrder>>> fetchByRecipeOrderIds(
    List<String> recipeOrderIds, {
    required String merchantId,
  });
}

class MealDeliveryOrderRemoteDSImpl implements MealDeliveryOrderRemoteDS {
  @override
  Future<List<MealDeliveryOrder>> fetchListByMerchant({
    required String merchantId,
    String? status,
    required int page,
    int pageSize = 20,
  }) async {
    try {
      final int offset = page * pageSize;
      var query = supabase
          .from('meal_delivery_order')
          .select(mealDeliveryOrderSelect)
          .eq('merchant_id', merchantId);
      if (status != null) {
        query = query.eq('status', status);
      }
      final response = await withNetworkTimeout(
        query
            .order('delivery_time', ascending: false)
            .range(offset, offset + pageSize - 1),
      );
      return MealDeliveryOrderMapper.parseList(response);
    } on TimeoutException catch (e) {
      print("fetchListByMerchant, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("fetchListByMerchant, fail, $e, $st");
      throw ShowableException('获取配送订单失败，未知错误！');
    }
  }

  @override
  Future<int> countByMerchant({
    required String merchantId,
    String? status,
  }) async {
    try {
      var query = supabase
          .from('meal_delivery_order')
          .select('id')
          .eq('merchant_id', merchantId);
      if (status != null) {
        query = query.eq('status', status);
      }
      final response = await withNetworkTimeout(
        query.count(CountOption.estimated),
      );
      return response.count;
    } on TimeoutException catch (e) {
      print("countByMerchant, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("countByMerchant, fail, $e, $st");
      throw ShowableException('获取订单数失败，未知错误！');
    }
  }

  @override
  Future<List<MealDeliveryOrder>> fetchByRecipeOrderId(
    String recipeOrderId, {
    required String merchantId,
  }) async {
    try {
      final response = await withNetworkTimeout(
        supabase
            .from('meal_delivery_order')
            .select(mealDeliveryOrderSelect)
            .eq('merchant_id', merchantId)
            .eq('recipe_order_id', recipeOrderId),
      );
      return MealDeliveryOrderMapper.parseList(response);
    } on TimeoutException catch (e) {
      print("fetchByRecipeOrderId, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("fetchByRecipeOrderId, fail, $e, $st");
      throw ShowableException('获取配送订单失败，未知错误！');
    }
  }

  @override
  Future<Map<String, List<MealDeliveryOrder>>> fetchByRecipeOrderIds(
    List<String> recipeOrderIds, {
    required String merchantId,
  }) async {
    // 去重 + 去掉空 id，避免拼出无意义的 in 查询
    final List<String> ids = recipeOrderIds
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return <String, List<MealDeliveryOrder>>{};
    }
    try {
      final response = await withNetworkTimeout(
        supabase
            .from('meal_delivery_order')
            .select(mealDeliveryOrderSelect)
            .eq('merchant_id', merchantId)
            .inFilter('recipe_order_id', ids),
      );
      return MealDeliveryOrderMapper.groupByRecipeOrderId(
        MealDeliveryOrderMapper.parseList(response),
      );
    } on TimeoutException catch (e) {
      print("fetchByRecipeOrderIds, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("fetchByRecipeOrderIds, fail, $e, $st");
      throw ShowableException('获取配送订单失败，未知错误！');
    }
  }
}
