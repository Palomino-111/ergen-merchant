/// 派单接口 `dispatch-delivery-order` 的响应模型
///
/// 服务端有两种「成功」形态，都返回 200：
/// - 首次派单：`provider_order_id` / `provider_task_id` / `provider_fee` / `status`
/// - 幂等返回：`already_dispatched: true`，此时**没有**产生新单、**没有**重复扣费
class DispatchResult {
  /// 是否是幂等返回（服务端已存在 provider_order_id，本次未重复下单）
  final bool alreadyDispatched;

  /// 快递100 的 orderId，回调对账主键
  final String? providerOrderId;

  /// 快递100 的 taskId，取消/加小费时必填
  final String? providerTaskId;

  /// 我方实际支出的配送成本（元）
  ///
  /// 注意：这是**我方成本**，不是向用户收取的 delivery_fee，展示时勿混用
  final double? providerFee;

  /// 派单成功后的配送单状态，固定为 awaiting_delivery
  final String status;

  DispatchResult({
    required this.alreadyDispatched,
    this.providerOrderId,
    this.providerTaskId,
    this.providerFee,
    required this.status,
  });

  factory DispatchResult.fromJson(Map<String, dynamic> json) {
    final fee = json['provider_fee'];
    return DispatchResult(
      alreadyDispatched: json['already_dispatched'] == true,
      providerOrderId: json['provider_order_id'],
      providerTaskId: json['provider_task_id'],
      // 服务端在 discountFee 不是数字时明确返回 null，不要写成 0 造成「假成本」
      providerFee: fee is num ? fee.toDouble() : null,
      status: json['status'] ?? 'awaiting_delivery',
    );
  }
}
