import 'dart:async';

/// 默认网络超时时间
///
/// dart:io 的 HttpClient 默认**没有超时**，网络不通时（例如国内直连 supabase.co）
/// 请求会一直挂着：界面表现就是「一直转圈 / 一直在加载」，而且不报任何错——
/// 登录点了没反应、下拉刷新收不回去，都是这个原因。
///
/// 所有后端请求都应该套一层超时，让失败尽快、带信息地暴露出来。
const Duration kNetworkTimeout = Duration(seconds: 15);

/// 给网络 future 加统一超时；超时抛 [TimeoutException]，由调用方转成用户可读的提示。
Future<T> withNetworkTimeout<T>(
  Future<T> future, {
  Duration timeout = kNetworkTimeout,
}) {
  return future.timeout(timeout);
}

/// 网络类错误（超时等）的统一文案
String networkErrorMessage(Object error) {
  if (error is TimeoutException) {
    return '请求超时：连不上服务器，请检查网络或代理';
  }
  return '网络异常，请稍后重试';
}
