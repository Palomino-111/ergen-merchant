class WithdrawalAccount {
  // 提现账号ID
  final String? id;

  // 商家ID
  final String merchantId;

  // 银行名称
  final String bankName;

  // 银行卡账号
  final String bankAccountNumber;

  // 银行卡户主
  final String bankAccountHolder;

  // 是否为默认提现账户
  final bool isDefault;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  WithdrawalAccount({
    this.id,
    required this.merchantId,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountHolder,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  // 从JSON解析
  factory WithdrawalAccount.fromJson(Map json) {
    return WithdrawalAccount(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      bankName: json['bank_name'] as String,
      bankAccountNumber: json['bank_account_number'] as String,
      bankAccountHolder: json['bank_account_holder'] as String,
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // 转换为JSON（与Supabase表结构匹配）
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id,
      'merchant_id': merchantId,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    // 如果对应字段为null，则移除，防止这种为null的脏数据插入到数据库中，或者是导致插入数据失败
    json.removeWhere((key, value) => value == null);
    return json;
  }

  // 复制并修改字段（用于状态更新）
  WithdrawalAccount copyWith({
    String? id,
    String? merchantId,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WithdrawalAccount(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
