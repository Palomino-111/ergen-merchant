import '../../models/meal_delivery_order.dart';
import '../data_source/remote/meal_delivery_order_remote_ds.dart';

/// 配送单仓库：统一承接「查询配送单」相关接口
///
/// 缓存策略（照抄消费端 OrderRepository，避免踩同样的坑）：
/// - 按 recipe_order_id 维度做内存缓存，命中直接返回；
/// - **空结果不写缓存**：一次失败的查询不该把「这单没有配送单」缓存住，
///   否则后续重试永远拿不到数据；
/// - 配送单被改动（改配送状态、改地址）之后必须显式失效，
///   否则会读到旧数据。
///
/// 分页列表 [fetchByMerchant] 刻意不走缓存：列表要求每次都能拿到最新状态，
/// 否则下拉刷新会「刷不动」。
abstract class MealDeliveryOrderRepository {
  /// 分页查询我店里的配送单（含 meal / dish_sku 嵌套，一次查询拿全）
  ///
  /// [statuses] 是状态集合（商家端一个分组 tab 对应一个集合），
  /// null 或空表示不过滤状态。[ascending] 为组内排序方向。
  /// [deliveryTimeFrom] 是送达时间下界（本地「今天 00:00」），
  /// 见 `DeliveryStatusGroup.fromTodayOnly`。
  Future<List<MealDeliveryOrder>> fetchByMerchant({
    required String merchantId,
    List<String>? statuses,
    required int page,
    int pageSize = 20,
    bool ascending = true,
    DateTime? deliveryTimeFrom,
  });

  /// 我店里的配送单总数（[statuses] 为 null 或空表示不过滤状态）
  ///
  /// [deliveryTimeFrom] 必须和列表用同一个值，否则角标和列表对不上。
  Future<int> countByMerchant({
    required String merchantId,
    List<String>? statuses,
    DateTime? deliveryTimeFrom,
  });

  /// 查某个食谱订单下我店里的配送单（带缓存）
  Future<List<MealDeliveryOrder>> getByRecipeOrderId(
    String recipeOrderId, {
    required String merchantId,
  });

  /// 批量查多个食谱订单的配送单（带缓存，未命中的合并成一次 in 查询）
  Future<Map<String, List<MealDeliveryOrder>>> getByRecipeOrderIds(
    List<String> recipeOrderIds, {
    required String merchantId,
  });

  /// 按 id 批量查配送单（不带缓存、不带嵌套），只用于把已有订单的状态刷新一遍。
  ///
  /// 和 [fetchByMerchant] 一样刻意不走缓存：它的唯一目的就是「拿到最新状态」，
  /// 走缓存等于什么都没刷。
  Future<List<MealDeliveryOrder>> fetchByIds(
    List<String> ids, {
    required String merchantId,
  });

  /// 清空全部配送单缓存
  void clearCache();

  /// 只失效指定食谱订单的配送单缓存
  void clearCacheFor(String recipeOrderId);

  /// 批量失效指定食谱订单的配送单缓存
  void clearCacheForAll(Iterable<String> recipeOrderIds);
}

class MealDeliveryOrderRepositoryImpl implements MealDeliveryOrderRepository {
  final MealDeliveryOrderRemoteDS _remote;

  /// recipe_order_id -> 该食谱订单下的配送单列表
  final Map<String, List<MealDeliveryOrder>> _cache = {};

  MealDeliveryOrderRepositoryImpl({
    required MealDeliveryOrderRemoteDS remote,
  }) : _remote = remote;

  @override
  Future<List<MealDeliveryOrder>> fetchByMerchant({
    required String merchantId,
    List<String>? statuses,
    required int page,
    int pageSize = 20,
    bool ascending = true,
    DateTime? deliveryTimeFrom,
  }) {
    return _remote.fetchListByMerchant(
      merchantId: merchantId,
      statuses: statuses,
      page: page,
      pageSize: pageSize,
      ascending: ascending,
      deliveryTimeFrom: deliveryTimeFrom,
    );
  }

  @override
  Future<int> countByMerchant({
    required String merchantId,
    List<String>? statuses,
    DateTime? deliveryTimeFrom,
  }) {
    return _remote.countByMerchant(
      merchantId: merchantId,
      statuses: statuses,
      deliveryTimeFrom: deliveryTimeFrom,
    );
  }

  @override
  Future<List<MealDeliveryOrder>> getByRecipeOrderId(
    String recipeOrderId, {
    required String merchantId,
  }) async {
    // 1. 内存缓存命中
    final cached = _cache[recipeOrderId];
    if (cached != null) {
      return cached;
    }

    // 2. 远程拉取（含 meal / dish_sku 嵌套）
    final orders = await _remote.fetchByRecipeOrderId(
      recipeOrderId,
      merchantId: merchantId,
    );

    // 3. 空结果不写缓存，避免一次失败查询阻塞后续重试
    if (orders.isNotEmpty) {
      _cache[recipeOrderId] = orders;
    }
    return orders;
  }

  @override
  Future<Map<String, List<MealDeliveryOrder>>> getByRecipeOrderIds(
    List<String> recipeOrderIds, {
    required String merchantId,
  }) async {
    final Map<String, List<MealDeliveryOrder>> result = {};
    final List<String> toFetch = [];
    for (final id in recipeOrderIds.toSet()) {
      if (id.isEmpty) {
        continue;
      }
      final cached = _cache[id];
      if (cached != null) {
        result[id] = cached;
      } else {
        toFetch.add(id);
      }
    }
    if (toFetch.isEmpty) {
      return result;
    }

    final byOrder = await _remote.fetchByRecipeOrderIds(
      toFetch,
      merchantId: merchantId,
    );

    // 空结果不写缓存（与单查一致，避免失败查询阻塞后续重试）
    for (final entry in byOrder.entries) {
      _cache[entry.key] = entry.value;
    }
    result.addAll(byOrder);
    return result;
  }

  @override
  Future<List<MealDeliveryOrder>> fetchByIds(
    List<String> ids, {
    required String merchantId,
  }) {
    return _remote.fetchByIds(ids, merchantId: merchantId);
  }

  @override
  void clearCache() => _cache.clear();

  @override
  void clearCacheFor(String recipeOrderId) {
    _cache.remove(recipeOrderId);
  }

  @override
  void clearCacheForAll(Iterable<String> recipeOrderIds) {
    for (final id in recipeOrderIds) {
      _cache.remove(id);
    }
  }
}
