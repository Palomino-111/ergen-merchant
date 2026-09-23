class Merchant {
  // 店铺id
  final String? id;

  // 用户（账号）id
  final String userId;

  // 营业/打烊 状态
  final bool isActive;

  // 店铺名称
  final String name;

  // 店铺地址信息
  // 店铺电话
  final String phone;

  // 省
  final String province;

  // 市
  final String city;

  // 区
  final String district;

  // 详细地址
  final String detailedAddress;

  // 经度
  final double longitude;

  // 纬度
  final double latitude;

  // 定位来源
  final String? positionSource;

  // 店铺地址信息结束

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Merchant({
    this.id,
    required this.userId,
    required this.isActive,
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailedAddress,
    required this.longitude,
    required this.latitude,
    this.positionSource,
    this.createdAt,
    this.updatedAt,
  });

  // 从JSON解析
  factory Merchant.fromJson(Map json) {
    return Merchant(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      isActive: json['is_active'] as bool,
      name: json['name'] as String,
      phone: json['phone'] as String,
      province: json['province'] as String,
      city: json['city'] as String,
      district: json['district'] as String,
      detailedAddress: json['detailed_address'] as String,
      longitude: json['longitude'] as double,
      latitude: json['latitude'] as double,
      positionSource: json['position_source'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // 转换为JSON（与Supabase表结构匹配）
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id,
      'user_id': userId,
      'is_active': isActive,
      'name': name,
      'phone': phone,
      'province': province,
      'city': city,
      'district': district,
      'detailed_address': detailedAddress,
      'longitude': longitude,
      'latitude': latitude,
      'position_source': positionSource,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    // 如果对应字段为null，则移除，防止这种为null的脏数据插入到数据库中，或者是导致插入数据失败
    json.removeWhere((key, value) => value == null);
    return json;
  }

  // 复制并修改字段（用于状态更新）
  Merchant copyWith({
    String? id,
    String? userId,
    bool? isActive,
    String? name,
    String? phone,
    String? province,
    String? city,
    String? district,
    String? detailedAddress,
    double? longitude,
    double? latitude,
    String? positionSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Merchant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      detailedAddress: detailedAddress ?? this.detailedAddress,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      positionSource: positionSource ?? this.positionSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
