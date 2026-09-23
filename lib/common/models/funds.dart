import '../utility/common.dart';

class Funds {
  // 提现账号ID
  final String? id;

  // 商家ID
  final String merchantId;

  // 剩余可提现金额
  final double availableFunds;

  // 冻结金额
  final double frozenFunds;

  // 待结算金额
  final double pendingFunds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Funds({
    this.id,
    required this.merchantId,
    required this.availableFunds,
    required this.frozenFunds,
    required this.pendingFunds,
    this.createdAt,
    this.updatedAt,
  });

  // 从JSON解析
  factory Funds.fromJson(Map json) {
    return Funds(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      availableFunds: parseDouble(json['available_funds'])!,
      frozenFunds: parseDouble(json['frozen_funds'])!,
      pendingFunds: parseDouble(json['pending_funds'])!,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // 转换为JSON（与Supabase表结构匹配）
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id,
      'merchant_id': merchantId,
      'available_funds': availableFunds,
      'frozen_funds': frozenFunds,
      'pending_funds': pendingFunds,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    // 如果对应字段为null，则移除，防止这种为null的脏数据插入到数据库中，或者是导致插入数据失败
    json.removeWhere((key, value) => value == null);
    return json;
  }

  // 复制并修改字段（用于状态更新）
  Funds copyWith({
    String? id,
    String? merchantId,
    double? availableFunds,
    double? frozenFunds,
    double? pendingFunds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Funds(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      availableFunds: availableFunds ?? this.availableFunds,
      frozenFunds: frozenFunds ?? this.frozenFunds,
      pendingFunds: pendingFunds ?? this.pendingFunds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
