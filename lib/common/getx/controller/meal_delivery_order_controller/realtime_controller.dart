import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../main.dart';
import '../../../data/repository/meal_delivery_order_repository.dart';
import '../../../models/meal_delivery_order.dart';
import 'all_meal_delivery_order_controller.dart';
import 'awaiting_preparation_meal_delivery_order_controller.dart';

/// 配送单状态的实时同步。
///
/// **解决什么问题**：商家派单之后，`delivering`（骑手已取餐）、`delivered`
/// （已送达）这些状态是快递100 回调在服务端写进去的，商家端不参与这个过程。
/// 没有订阅的时候，屏幕上的状态只能靠商家自己下拉刷新才会变——
/// 不刷就一直停在「待配送」，等于商家根本不知道餐什么时候被取走、送到了没有。
///
/// **怎么做**：订阅 `meal_delivery_order` 的 UPDATE，按 `merchant_id` 做服务端
/// 过滤（只收自己店的单），收到之后交给两个列表控制器做**局部更新**，
/// 不触发任何整表刷新，所以列表不会闪、不会跳。
///
/// **服务端前置条件**（缺一个都会「静默失效」——不报错，只是永远收不到）：
/// 1. 表必须加进 Realtime publication：
///    `alter publication supabase_realtime add table public.meal_delivery_order;`
/// 2. RLS 的 SELECT 策略必须对商家放行。
///    注意 UPDATE 事件要求**新旧两行都通过策略**，所以策略里千万不要带
///    `status` 这种会随更新变化的列，否则「状态一变就收不到」。
///    当前线上策略是按归属（recipe_order / merchant）判断的，没有这个问题。
///
/// **已知边界**：Realtime 是长连接，App 被系统切到后台会挂起连接，
/// 期间的变化既收不到、重连后也不会补推。所以回到前台时必须主动补一次
/// （见 [didChangeAppLifecycleState] + [_resync]），下拉刷新也照旧保留。
///
/// **没做的事**：只订阅 UPDATE。新订单到来（INSERT）不会自己出现在列表里，
/// 还需要商家下拉刷新——那是另一个需求，要加的话在这里补一个 INSERT 订阅、
/// 并让列表控制器决定插到哪个位置（涉及分页顺序，不是无脑 insert 就完事）。
class MealDeliveryOrderRealtimeController extends GetxController
    with WidgetsBindingObserver {
  static MealDeliveryOrderRealtimeController get to => Get.find();

  /// 订阅的表名
  static const String _table = 'meal_delivery_order';

  RealtimeChannel? _channel;

  /// 当前订阅的店铺 id，用来判断要不要重建订阅
  String? _merchantId;

  /// 是否曾经切到过后台（只有切过才需要在回前台时补数据）
  bool _leftForeground = false;

  /// 是否已订阅（排查问题时用）
  bool get isSubscribed => _channel != null;

  @override
  void onInit() {
    super.onInit();
    // 回前台补数据要靠 App 生命周期回调
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.onClose();
  }

  /// 开始订阅指定店铺的配送单变化。
  ///
  /// 重复用同一个 merchantId 调用是幂等的，不会重复建连；
  /// 换店铺会先断开旧订阅，避免拿旧身份继续收推送。
  void start(String merchantId) {
    // 显式把当前会话的 access_token 交给 Realtime 连接。
    //
    // 为什么不能只靠 SDK 内部「auth 事件 → realtime.setAuth」那条链路：
    // 它和这里的「订阅建连」是由同一个 auth 事件触发的，两者存在竞态——
    // channel 可能拿着旧 token（anon key）就去 join 了。而 token 没进到
    // realtime 的后果是**静默的**：服务端 RLS 按 anon 角色判定策略，
    // 一行都不通过，事件被丢掉，客户端却仍然是 SUBSCRIBED，一个错都不报。
    // 社区里大量「SUBSCRIBED 但收不到任何事件」都是这个原因，
    // Supabase 官方给的解法就是显式调一次 setAuth。
    //
    // setAuth 在 token 非空时是**同步生效**的（token 非空时不会走到 await），
    // 所以这里不用等它完成，紧接着 subscribe 拿到的就是新 token。
    // 每次都同步一遍（而不是只在新建订阅时）：冷启动时会话可能后到、
    // token 也会被 SDK 自动续期，已建的连接需要拿到新 token。
    final String? accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken != null) {
      unawaited(supabase.realtime.setAuth(accessToken));
    }
    print(
      'MealDeliveryOrderRealtime, start, merchantId=$merchantId, '
      'hasAccessToken=${accessToken != null}',
    );

    if (_merchantId == merchantId && _channel != null) {
      return;
    }
    stop();
    _merchantId = merchantId;
    _channel = supabase
        .channel('meal-delivery-order-$merchantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: merchantId,
          ),
          callback: (payload) => _applyRow(payload.newRecord),
        )
        .subscribe((status, error) {
          // 订阅是「静默失败」的重灾区：连不上/没权限都只是收不到消息，
          // 不打印的话出了问题完全无从查起
          print('MealDeliveryOrderRealtime, subscribe: $status, $error');
        });
  }

  /// 断开订阅（退出登录 / 换账号时调用）
  void stop() {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    _merchantId = null;
    if (channel != null) {
      unawaited(supabase.removeChannel(channel));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 只有真的被切到后台才算。inactive 在弹权限框、下拉通知栏、
    // 进任务管理器预览时都会触发，每次都补一次会白发一堆请求。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftForeground = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _leftForeground) {
      _leftForeground = false;
      unawaited(_resync());
    }
  }

  /// 把一行配送单数据同步到两个列表里对应的那一单
  void _applyRow(Map<String, dynamic> row) {
    if (row.isEmpty) {
      return;
    }
    AllMealDeliveryOrderController.to.applyRealtimeUpdate(row);
    AwaitingPreparationMealDeliveryOrderController.to.applyRealtimeUpdate(row);
  }

  /// 回到前台时补一次数据。
  ///
  /// 只重查**当前已经加载在内存里的那些单**，而不是像下拉刷新那样整表重拉：
  /// 整表重拉会把列表换成第一页，商家如果往上翻了好几页，回来就会发现自己
  /// 被拉回顶部、刚才看的那条不见了。按 id 重查则列表内容、顺序、
  /// 滚动位置全都不动，只有状态字会变。
  Future<void> _resync() async {
    final String? merchantId = _merchantId;
    if (merchantId == null) {
      return;
    }

    // 断线重连不在这里管：RealtimeClient 自己有心跳和自动重连，
    // 通道会在连接恢复后自动重新 join。这里只负责把「挂起期间漏掉的数据」补上。
    final List<String> ids = <String>[
      ...AllMealDeliveryOrderController.to.allMealDeliveryOrders
          .map((MealDeliveryOrder order) => order.id)
          .whereType<String>(),
      ...AwaitingPreparationMealDeliveryOrderController
          .to.awaitingPreparationMealDeliveryOrders
          .map((MealDeliveryOrder order) => order.id)
          .whereType<String>(),
    ];
    if (ids.isEmpty) {
      return;
    }

    try {
      final List<MealDeliveryOrder> orders =
          await Get.find<MealDeliveryOrderRepository>().fetchByIds(
        ids,
        merchantId: merchantId,
      );
      for (final MealDeliveryOrder order in orders) {
        // toJson 出来就是表行的形状（不含 meal/dish_sku 嵌套，
        // 那几个字段本来也不参与序列化），所以直接复用局部更新那条路
        _applyRow(order.toJson());
      }
    } catch (e, st) {
      // 补数据失败不打扰商家：下拉刷新仍然可以手动兜底
      print('MealDeliveryOrderRealtime, resync fail, $e, $st');
    }
  }
}
