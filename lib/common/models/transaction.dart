import 'package:zheergen_merchant_end/common/utility/common.dart';

class Transaction {
  // 流水id
  final String? id;

  // 商家ID
  final String merchantId;

  // 餐配送订单id
  final String mealDeliveryOrderId;

  // 流水类型
  final String type;

  // 流水金额
  final double amount;

  // 流水变动后的可用资金
  final double availableFundsAfter;

  // 流水描述
  final String description;

  // 流水创建时间
  final DateTime? createdAt;

  Transaction({
    this.id,
    required this.merchantId,
    required this.mealDeliveryOrderId,
    required this.type,
    required this.amount,
    required this.availableFundsAfter,
    required this.description,
    this.createdAt,
  });

  factory Transaction.fromJson(Map json) {
    return Transaction(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      mealDeliveryOrderId: json['meal_delivery_order_id'] as String,
      type: json['type'] as String,
      amount: parseDouble(json['amount'])!,
      availableFundsAfter: parseDouble(json['available_funds_after'])!,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // 转换为JSON（与Supabase表结构匹配）
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id,
      'merchant_id': merchantId,
      'meal_delivery_order_id': mealDeliveryOrderId,
      'type': type,
      'amount': amount,
      'available_funds_after': availableFundsAfter,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
    // 如果对应字段为null，则移除，防止这种为null的脏数据插入到数据库中，或者是导致插入数据失败
    json.removeWhere((key, value) => value == null);
    return json;
  }

  // 复制并修改字段（用于状态更新）
  Transaction copyWith({
    String? id,
    String? merchantId,
    String? mealDeliveryOrderId,
    String? type,
    double? amount,
    double? availableFundsAfter,
    String? description,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      mealDeliveryOrderId: mealDeliveryOrderId ?? this.mealDeliveryOrderId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      availableFundsAfter: availableFundsAfter ?? this.availableFundsAfter,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
