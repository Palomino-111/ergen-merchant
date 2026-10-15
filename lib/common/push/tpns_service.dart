import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tpns_flutter_plugin/tpns_flutter_plugin.dart';

import '../data/repository/merchant_device_repository.dart';

/// TPNS 推送服务，全局单例通过 [TpnsService.I] 访问。
///
/// 只负责"收发推送"和"上报 token"：
///   - 初始化、注册回调、前台展示、点击解析
///   - token 就绪时上报到 merchant_device
///
/// **不负责**页面跳转（由 main.dart 注入 onOrderClicked 决定跳哪）。
/// **不依赖** getx/controller 层，需要读 merchantId 时通过
/// [merchantIdProvider] 注入函数，把"从哪拿"的决定权交给组装层。
///
/// 推送仅在 Android 生效，其余平台调用本类的公开方法均直接返回。
class TpnsService {
  TpnsService._();

  static final TpnsService I = TpnsService._();

  final XgFlutterPlugin _plugin = XgFlutterPlugin();

  /// 是否已经 addEventHandler 过。
  /// 为什么要这个标记：init() 是幂等的（App 启动、登录成功都会调），
  /// 但 addEventHandler 重复调用可能导致回调被注册两次
  /// （一次推送弹两个窗）。所以首次注册，后续只 startXg。
  bool _handlerRegistered = false;

  /// 最新拿到的 token。退出登录时清掉。
  String? _currentToken;

  /// 最近一次**成功上报**的 token + merchantId。
  /// 用来去重：token 和 merchantId 都没变时不再重复上报，减少网络往返。
  String? _uploadedToken;
  String? _uploadedMerchantId;

  /// 冷启动未消费的跳转 orderId。
  ///
  /// 场景：App 被杀 → 点通知 → 系统拉起 App → TPNS 的 xgPushClickAction
  /// 可能在首页 UI ready 之前就触发，此时回调无处可跳，先缓存下来，
  /// 等调用方在合适时机调 [consumePendingOrderId] 消费。
  String? _pendingOrderId;

  /// 由 main.dart 注入：返回当前 merchantId（未登录/未就绪时返回 null）。
  /// 用函数而不是直接读 controller：common 层不能依赖业务层。
  String? Function()? merchantIdProvider;

  /// 点击通知回调，由 main.dart 在初始化时注入。
  /// 参数是从推送 payload 里解析出来的 orderId。
  void Function(String orderId)? onOrderClicked;

  /// 初始化 / 启动 TPNS。**幂等**：
  ///   - 首次调用：注册回调 + startXg
  ///   - 后续调用：只重新 startXg（处理退出登录后再次登录）
  /// 仅 Android 生效，其余平台直接返回。
  ///
  /// AccessID / AccessKey 走 build.gradle 里的 manifestPlaceholders，
  /// startXg 传空串即可（SDK 会从 manifest 读），**不要**在 Dart 里硬编码。
  Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // 先确保回调已注册（只注册一次）
    if (!_handlerRegistered) {
      _handlerRegistered = true;
      _registerHandlers();
      // 开发期打开底层 SDK 日志，发布前应调 setDebug(false)
      _plugin.setEnableDebug(true);
    }

    try {
      _plugin.startXg('', '');
      print('🔵 [TPNS] startXg 已调用');
      // 通知权限不阻塞初始化，延后异步请求
      _requestPermission();
    } catch (e, st) {
      print('🔴 [TPNS] startXg 失败: $e\n$st');
    }
  }

  /// 停止 TPNS 推送并清掉内存中的 token（退出登录时调）。
  ///
  /// 为什么退出登录要 stop：不清的话服务端还会继续推给这个设备，
  /// 商家已经登出但通知栏还在响，体验很差。
  /// 下次登录时 main/merchant 侧会再调 [init] 重新 startXg。
  void stop() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _plugin.stopXg();
    } catch (e, st) {
      print('🔴 [TPNS] stopXg 失败: $e\n$st');
    }
    clearToken();
  }

  /// 尝试上报当前 token 到 merchant_device（如果 token 和 merchantId 都就绪）。
  ///
  /// 调用时机：
  ///   - token 就绪时（onRegisteredDeviceToken 内部自动调）
  ///   - merchantId 就绪时（MerchantController 拿到 merchantId 后调）
  /// 两条路径都调到同一个方法，谁晚谁触发上报。
  Future<void> tryUploadPendingToken() async {
    print('🔵 [TPNS] tryUploadPendingToken 被调用, _currentToken=$_currentToken');
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final token = _currentToken;
    if (token == null || token.isEmpty) {
      // token 还没就绪，等 onRegisteredDeviceToken 回调再触发
      return;
    }

    final merchantId = merchantIdProvider?.call();
    if (merchantId == null || merchantId.isEmpty) {
      // merchantId 还没就绪，等 MerchantController 拿到后再触发
      return;
    }

    // 同 token + 同 merchantId 已上报过，不重复
    if (_uploadedToken == token && _uploadedMerchantId == merchantId) {
      return;
    }

    try {
      String? appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.version;
      } catch (_) {
        // 拿不到版本号不影响主流程
      }

      await Get.find<MerchantDeviceRepository>().registerDevice(
        merchantId: merchantId,
        tpnsToken: token,
        platform: 'android',
        appVersion: appVersion,
      );
      _uploadedToken = token;
      _uploadedMerchantId = merchantId;
      print('🔵 [TPNS] token 上报成功: merchant=$merchantId, token=$token');
    } catch (e, st) {
      // 上报失败不阻塞：下次 token 回调 / 登录都会重试。
      // 不在这里做重试队列：token 上报的频率极低（装机一次、换账号一次），
      // 靠"下一次机会"就够了。
      print('🔴 [TPNS] token 上报失败: $e\n$st');
    }
  }

  /// 主动获取当前设备的 TPNS token（可能还没注册完成，返回 null）。
  Future<String?> getToken() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    if (_currentToken != null) return _currentToken;
    try {
      final t = await XgFlutterPlugin.xgToken;
      _currentToken = t;
      return t;
    } catch (e) {
      print('🔴 [TPNS] 获取 Token 失败: $e');
      return null;
    }
  }

  /// 清掉内存里的 token 和上报记录（退出登录时由 [stop] 调用）。
  void clearToken() {
    _currentToken = null;
    _uploadedToken = null;
    _uploadedMerchantId = null;
  }

  /// 消费冷启动缓存的跳转 orderId。
  ///
  /// 调用方应在首页 ready 后调一次；如果返回非 null，
  /// 就把跳转逻辑走一遍。返回后内部缓存即清空，重复调用返回 null。
  String? consumePendingOrderId() {
    final id = _pendingOrderId;
    _pendingOrderId = null;
    return id;
  }

    /// 把待跳转的 orderId 存起来（由 main.dart 在 MainLogic 未就绪时调用）。
  ///
  /// 为什么需要这个：onOrderClicked 在冷启动时可能早于 MainPage 创建，
  /// 此时 Get.find<MainLogic>() 拿不到实例，需要把 orderId 暂存，
  /// 等 MainPage 首帧后消费。
  void setPendingOrderId(String orderId) {
    _pendingOrderId = orderId;
    print('🟡 [TPNS] 暂存 pending orderId: $orderId');
  }

  /// 开关底层 SDK 调试日志（发布前应关闭）。
  void setDebug(bool enable) => _plugin.setEnableDebug(enable);

  // ---------- 内部方法 ----------

  void _registerHandlers() {
    try {
      _plugin.addEventHandler(
        onRegisteredDeviceToken: (String token) async {
          print('🔵 [TPNS] 注册成功, token: $token');
          _currentToken = token;
          // token 就绪 → 尝试上报（如果 merchantId 已就绪）
          await tryUploadPendingToken();
        },
               onRegisteredDone: (String msg) async {
          print('🔵 [TPNS] 注册完成: $msg');
          // 部分版本/设备上 onRegisteredDeviceToken 不会自动触发，
          // 需要在注册完成后主动取一次。取到了当 token 就绪处理，
          // 取不到就等 onRegisteredDeviceToken 回调（两条路都覆盖）。
          try {
            final t = await XgFlutterPlugin.xgToken;
            print('🔵 [TPNS] 主动取 token: $t');
            if (t != null && t.isNotEmpty) {
              _currentToken = t;
              await tryUploadPendingToken();
            }
          } catch (e) {
            print('🔴 [TPNS] 主动取 token 失败: $e');
          }
        },
        onReceiveNotificationResponse: (Map<String, dynamic> msg) async {
          print('🔵 [TPNS] 前台收到通知: $msg');
          // Android 前台不会自动弹通知，必须自己展示；
          // 不处理的话表现就是"App 开着反而没提醒"，是最容易被投诉的体验 bug
          _showInAppNotification(msg);
        },
        xgPushClickAction: (Map<String, dynamic> msg) async {
          print('🔵 [TPNS] 点击通知: $msg');
          _handleClick(msg);
        },
        onReceiveMessage: (Map<String, dynamic> msg) async {
          // 透传消息不弹通知，本项目用不到，仅打印避免误判"推送没到"
          print('🔵 [TPNS] 收到透传消息 ⚠️不会弹窗: $msg');
        },
        unRegistered: (String msg) async {
          print('🔵 [TPNS] 反注册: $msg');
        },
      );
    } catch (e, st) {
      print('🔴 [TPNS] 注册回调失败: $e\n$st');
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.notification.status;
      print('🔵 [TPNS] 通知权限状态: $status');
      if (status.isDenied) {
        final result = await Permission.notification.request();
        print('🔵 [TPNS] 请求通知权限结果: $result');
        if (result.isPermanentlyDenied) {
          print('🔴 [TPNS] 通知权限被永久拒绝，请到系统设置中手动开启');
          // 只在永久拒绝时才跳设置：正常拒绝是用户的合理选择，
          // 每次都弹设置反而会骚扰
          await openAppSettings();
        }
      }
    } catch (e) {
      print('🔴 [TPNS] 权限请求异常: $e');
    }
  }

  /// 前台展示应用内提醒：弹窗 + 震动 + 提示音。
  void _showInAppNotification(Map<String, dynamic> msg) {
    try {
      // 震动 + 提示音：让商家在"没盯着屏幕"时也能察觉
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);

      final title = (msg['title'] as String?)?.trim().isNotEmpty == true
          ? msg['title'] as String
          : '该备餐了';
      final body = (msg['body'] as String?)?.trim().isNotEmpty == true
          ? msg['body'] as String
          : '有新订单需要备餐';
      final orderId = _extractOrderId(msg);

      BotToast.showNotification(
        // 8 秒：足够商家从别的界面切回来点，又不至于一直挂着挡视线
        duration: const Duration(seconds: 8),
        title: (_) => Text(title),
        subtitle: (_) => Text(body),
        onTap: () {
          BotToast.cleanAll();
          if (orderId != null) {
            _handleClickOrder(orderId);
          }
        },
      );
    } catch (e, st) {
      print('🔴 [TPNS] 前台通知展示失败: $e\n$st');
    }
  }

  void _handleClick(Map<String, dynamic> msg) {
    final orderId = _extractOrderId(msg);
    if (orderId == null) {
      print('🟡 [TPNS] 点击通知但未解析出 orderId，忽略');
      return;
    }
    _handleClickOrder(orderId);
  }

  void _handleClickOrder(String orderId) {
    final cb = onOrderClicked;
    if (cb != null) {
      cb(orderId);
      return;
    }
    // 冷启动：onOrderClicked 还没被 main.dart 注入，先缓存
    _pendingOrderId = orderId;
    print('🟡 [TPNS] onOrderClicked 尚未注册，缓存 pending: $orderId');
  }

  /// 从推送 payload 里找 orderId。
  ///
  /// TPNS 的自定义字段可能落在这几个位置（不同版本 SDK、不同发送方式不一样），
  /// 按优先级逐个找一遍，尽量不因为 SDK 小版本差异导致解析不到：
  ///   1. 顶层（某些情况下 SDK 直接展开）
  ///   2. custom 字符串（JSON）
  ///   3. customContent Map
  String? _extractOrderId(Map<String, dynamic> msg) {
    final direct = msg['orderId'];
    if (direct is String && direct.isNotEmpty) return direct;

    final custom = msg['custom'];
    if (custom is String && custom.isNotEmpty) {
      try {
        final decoded = jsonDecode(custom);
        if (decoded is Map) {
          final id = decoded['orderId'];
          if (id is String && id.isNotEmpty) return id;
        }
      } catch (_) {
        // 不是 JSON，忽略
      }
    }

    final customContent = msg['customContent'];
    if (customContent is Map) {
      final id = customContent['orderId'];
      if (id is String && id.isNotEmpty) return id;
    }

    return null;
  }
}