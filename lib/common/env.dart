import 'package:flutter/foundation.dart';

/// 环境配置（照抄消费端 `Env` 的做法：默认值 = 当前开发环境，可用 --dart-define 覆盖）
///
/// 为什么需要它：Supabase 的域名在国内经常连不上（实测直连失败、走代理才通），
/// 手机又不像 PC 那样方便挂代理，所以必须能不改代码就切换后端地址。
///
/// 常用示例：
/// ```bash
/// # 指向另一个 Supabase 项目 / 国内可达的中转地址
/// fvm flutter run --dart-define=SUPABASE_URL=https://xxx.example.com
///
/// # 让 App 走本机代理（PC 上的 Clash 等，需勾选 Allow LAN）
/// fvm flutter run --dart-define=HTTP_PROXY=192.168.1.10:7890
///
/// # 未登录时用指定店铺跑通页面（调试）
/// fvm flutter run --dart-define=DEBUG_MERCHANT_ID=67320155-5301-4bd5-8765-946259723c07
/// ```
class Env {
  Env._();

  /// Supabase 项目 URL（PostgREST 接口基址）
  ///
  /// 2026-09 起后端换成这个新项目；旧项目 `redkowdpjduavcmzjfep` 里没有商家端账号，
  /// 连旧项目会一直报 `Invalid login credentials`。
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wmioylfpdbdwnbybkpju.supabase.co',
  );

  /// Supabase key（新格式 publishable key）
  ///
  /// 字段名沿用 `supabaseAnonKey` 是历史原因，值已经是 `sb_publishable_...`。
  /// 它是面向客户端的公开 key，但仍可以用 `--dart-define` 覆盖。
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_nUsNeaF2lPNRywuwqqSX9g_4T8uvxpC',
  );

  /// 调试用的 HTTP 代理（`host:port`，留空表示直连）
  ///
  /// dart:io 默认不走系统代理，网络被墙时只能靠这个把请求导出去。
  static const String httpProxy = String.fromEnvironment('HTTP_PROXY');

  /// 调试用兜底店铺 id：未登录时也能把「生产计划」等页面跑起来
  ///
  /// release 构建下恒为 null，不影响线上；不传 define 时同样为 null（行为与以前一致）。
  static const String _debugMerchantId =
      String.fromEnvironment('DEBUG_MERCHANT_ID');

  static const String? debugMerchantId =
      kReleaseMode || _debugMerchantId == '' ? null : _debugMerchantId;
}
