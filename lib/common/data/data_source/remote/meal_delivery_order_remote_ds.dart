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
  /// 分页查我店里的配送单。
  ///
  /// [statuses] 是一个**状态集合**（对应商家端的一个分组 tab，见
  /// `DeliveryStatusGroup`）：null 或空表示不过滤状态（全部）。
  /// 用集合而不是单个 status，是因为「待制作」「在途」「已结束」这三组
  /// 各自都包含不止一个状态，分组过滤必须下推到服务端——
  /// 客户端过滤只能过滤已加载的那一页，会骗人（筛选出 3 条不代表只有 3 条）。
  ///
  /// [ascending] 为 true 时按预定送达时间升序（马上要做的在前），
  /// false 为降序（最近结束的在前）。
  ///
  /// [deliveryTimeFrom] 是送达时间的下界（本地时间的「今天 00:00」），
  /// null 表示不限制。见 `DeliveryStatusGroup.fromTodayOnly`：
  /// 未结束的组必须带上它，否则历史僵尸单会占满屏幕。
  ///
  /// 一次查询就带出 meal / meal_dish / dish_sku 嵌套，避免每个 item 再查餐品（N+1）。
  Future<List<MealDeliveryOrder>> fetchListByMerchant({
    required String merchantId,
    List<String>? statuses,
    required int page,
    int pageSize = 20,
    bool ascending = true,
    DateTime? deliveryTimeFrom,
  });

  /// 我店里的配送单总数（[statuses] 为 null 或空表示不过滤状态）。
  ///
  /// [deliveryTimeFrom] 必须和列表用同一个值：角标是「还有多少单要做」，
  /// 两个条件不一致会出现「角标显示 5511，列表里只有十几个」。
  ///
  /// 用 exact count 而不是 estimated：这是页面上的角标，商家会拿它当准数，
  /// 而 estimated 取的是执行计划的估算值，过滤条件一多就明显偏；
  /// 这张表量级只有几千行，精确 count 的代价可以忽略。
  Future<int> countByMerchant({
    required String merchantId,
    List<String>? statuses,
    DateTime? deliveryTimeFrom,
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

  /// 按 id 批量查我店里的配送单，**只要标量字段**（不带 meal/dish_sku 嵌套）。
  ///
  /// 用途：App 从后台回到前台时，把内存里已有订单的状态刷新一遍。
  /// 和分页列表 [fetchListByMerchant] 的关键区别是它**不是整表重拉**——
  /// 列表内容、顺序、滚动位置都不变，只把每条的状态换成最新的，
  /// 所以商家不会遇到「切个后台回来列表跳回顶部」。
  Future<List<MealDeliveryOrder>> fetchByIds(
    List<String> ids, {
    required String merchantId,
  });
}

class MealDeliveryOrderRemoteDSImpl implements MealDeliveryOrderRemoteDS {
  /// [fetchByIds] 一次 in 查询最多带多少个 id。
  ///
  /// PostgREST 走 GET，id 全在 query string 里；一个 uuid 36 个字符，
  /// 几百个就接近常见网关/代理的 URL 长度上限了，所以分批发。
  static const int _idBatchSize = 100;

  @override
  Future<List<MealDeliveryOrder>> fetchListByMerchant({
    required String merchantId,
    List<String>? statuses,
    required int page,
    int pageSize = 20,
    bool ascending = true,
    DateTime? deliveryTimeFrom,
  }) async {
    try {
      final int offset = page * pageSize;
      var query = supabase
          .from('meal_delivery_order')
          .select(mealDeliveryOrderSelect)
          .eq('merchant_id', merchantId);
      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }
      if (deliveryTimeFrom != null) {
        // 必须转 UTC 后再序列化：本地时间直接 toIso8601String() 出来是个
        // 不带时区的裸串，服务端会按它自己的时区解释，国内会整体偏 8 小时
        query = query.gte(
          'delivery_time',
          deliveryTimeFrom.toUtc().toIso8601String(),
        );
      }
      final response = await withNetworkTimeout(
        query
            .order('delivery_time', ascending: ascending)
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
    List<String>? statuses,
    DateTime? deliveryTimeFrom,
  }) async {
    try {
      var query = supabase
          .from('meal_delivery_order')
          .select('id')
          .eq('merchant_id', merchantId);
      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }
      if (deliveryTimeFrom != null) {
        query = query.gte(
          'delivery_time',
          deliveryTimeFrom.toUtc().toIso8601String(),
        );
      }
      final response = await withNetworkTimeout(
        query.count(CountOption.exact),
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

  @override
  Future<List<MealDeliveryOrder>> fetchByIds(
    List<String> ids, {
    required String merchantId,
  }) async {
    // 去重 + 去掉空 id，避免拼出无意义的 in 查询
    final List<String> uniqueIds = ids
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uniqueIds.isEmpty) {
      return <MealDeliveryOrder>[];
    }
    try {
      final List<MealDeliveryOrder> orders = <MealDeliveryOrder>[];
      for (int start = 0; start < uniqueIds.length; start += _idBatchSize) {
        final int end = start + _idBatchSize;
        final List<String> batch = uniqueIds.sublist(
          start,
          end > uniqueIds.length ? uniqueIds.length : end,
        );
        final response = await withNetworkTimeout(
          supabase
              .from('meal_delivery_order')
              // 这里刻意不带嵌套：调用方只需要拿状态去更新已有对象，
              // 嵌套字段由本地那份保留（见 mergeDeliveryOrderRow）
              .select('*')
              // merchant_id 条件不能省：id 是调用方传进来的，
              // 归属过滤是这一层自己的责任，不能只指望 RLS 兜底
              .eq('merchant_id', merchantId)
              .inFilter('id', batch),
        );
        orders.addAll(MealDeliveryOrderMapper.parseList(response));
      }
      return orders;
    } on TimeoutException catch (e) {
      print("fetchByIds, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("fetchByIds, fail, $e, $st");
      throw ShowableException('获取配送订单失败，未知错误！');
    }
  }
}
