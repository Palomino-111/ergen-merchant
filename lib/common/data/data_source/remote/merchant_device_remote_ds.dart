import 'dart:async';

import '../../../../main.dart';
import '../../../exception/showable_exception.dart';
import '../../../utility/network.dart';

// 商家推送设备（TPNS token 的落库形态）
//
// 一个商家可能有多台手机登录（老板 + 店员 + 备用机），
// 所以 merchant_id 与设备是 1:N，服务端推送时按 merchant_id 全量推。
//
// 唯一键刻意放在 tpns_token 上，而不是 (merchant_id, tpns_token)：
// 卸载重装会换 token，旧 token 就废了；如果允许多条同 token，
// 会攒出一堆死设备，推送时还得去重和清理。一个 token 只属于一台设备，
// 所以整表唯一即可。
class MerchantDevice {
  // 主键
  final String? id;

  // 商家 id（归属）
  final String? merchantId;

  // TPNS 分配的设备 token
  final String? tpnsToken;

  // 平台（目前只有 android，iOS 后续再排）
  final String? platform;

  // 上报时的 App 版本号，方便排查"某个版本收不到"这类问题
  final String? appVersion;

  // 最近一次上报时间，供服务端判断设备是否还在用
  final DateTime? lastActiveAt;

  // 创建时间
  final DateTime? createdAt;

  MerchantDevice({
    this.id,
    this.merchantId,
    this.tpnsToken,
    this.platform,
    this.appVersion,
    this.lastActiveAt,
    this.createdAt,
  });

  factory MerchantDevice.fromJson(Map<String, dynamic> json) {
    return MerchantDevice(
      id: json['id'],
      merchantId: json['merchant_id'],
      tpnsToken: json['tpns_token'],
      platform: json['platform'],
      appVersion: json['app_version'],
      // 表结构里这两个列是 not null default now()，理论上不会 null，
      // 但沿用订单 model 的防御性写法（线上真的出现过允许 null 的列），
      // 免得将来某次表结构调整导致整条解析失败
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (id != null) {
      json['id'] = id;
    }
    if (merchantId != null) {
      json['merchant_id'] = merchantId;
    }
    if (tpnsToken != null) {
      json['tpns_token'] = tpnsToken;
    }
    if (platform != null) {
      json['platform'] = platform;
    }
    if (appVersion != null) {
      json['app_version'] = appVersion;
    }
    if (lastActiveAt != null) {
      json['last_active_at'] = lastActiveAt?.toIso8601String();
    }
    if (createdAt != null) {
      json['created_at'] = createdAt?.toIso8601String();
    }
    return json;
  }
}

/// 商家推送设备远程数据源（PostgREST 直查，不走 Edge Function）
///
/// 商家端只有「上报本机 token」这一个写操作：
/// 谁登录了就把当前设备的 token 记在谁名下，服务端推送时按 merchant_id 找设备。
abstract class MerchantDeviceRemoteDS {
  /// 上报（新增或更新）一台设备。
  ///
  /// 必须用 upsert 而不是 insert：同一条记录会被反复上报
  /// （App 启动、登录、token 变化都会走一次），而 tpns_token 是唯一键，
  /// 重复上报要落在同一行上，否则会攒出一堆同 token 的重复行。
  ///
  /// 换账号登录时同一台设备的 token 不变、merchant_id 变了，
  /// 所以 merchant_id 也要跟着覆盖（一台设备同一时间只归属一个商家）。
  Future<void> upsertDevice({
    required String merchantId,
    required String tpnsToken,
    required String platform,
    String? appVersion,
  });
}

class MerchantDeviceRemoteDSImpl implements MerchantDeviceRemoteDS {
  @override
  Future<void> upsertDevice({
    required String merchantId,
    required String tpnsToken,
    required String platform,
    String? appVersion,
  }) async {
    try {
      await withNetworkTimeout(
        supabase.from('merchant_device').upsert(
          {
            'merchant_id': merchantId,
            'tpns_token': tpnsToken,
            'platform': platform,
            if (appVersion != null && appVersion.isNotEmpty)
              'app_version': appVersion,
            // 服务端靠这个字段判断设备是否还在用（清理僵尸设备）
            'last_active_at': DateTime.now().toUtc().toIso8601String(),
          },
          // 冲突列必须显式指定：表上的唯一索引在 tpns_token 上，
          // 默认按主键 id 判冲突的话，重复上报会因为 id 不同而插出新行
          onConflict: 'tpns_token',
        ),
      );
    } on TimeoutException catch (e) {
      print("upsertDevice, timeout, $e");
      throw ShowableException(networkErrorMessage(e));
    } catch (e, st) {
      print("upsertDevice, fail, $e, $st");
      throw ShowableException('上报推送设备失败，未知错误！');
    }
  }
}
