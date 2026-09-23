// import 'package:flutter_travel_concept/models/meal.dart';
// import 'dish_sku.dart';
// 餐食配送订单
class MealDeliveryOrder {
  // 餐配送订单id
  final String? id;

  // 商家id
  final String? merchantId;

  // 食谱订单id
  final String? recipeOrderId;

  // 餐品id
  final String? mealId;

  // meal快照
  final Map<String, dynamic> mealSnapshot;

  // 收货人姓名
  String recipientName;

  // 收货人电话
  String phone;

  // 省
  String province;

  // 市
  String city;

  // 区
  String district;

  // 详细地址
  String detailedAddress;

  // 地址的经度
  double longitude;

  // 地址的纬度
  double latitude;

  // 预定送达时间
  DateTime deliveryTime;

  // 实际送达时间
  final DateTime? deliveredAt;

  // 配送单状态
  final String? status;

  // 创建时间
  final DateTime? createdAt;

  // 最后更新时间
  final DateTime? updatedAt;

  // 直接关联菜品（按sort_order排序）
  // List<DishSku> dishSkus = [];

  // 餐名
  String mealName = "";

  // 配送单对应的Meal对象
  // Meal? meal;

  MealDeliveryOrder({
    this.id,
    this.merchantId,
    this.recipeOrderId,
    this.mealId,
    required this.mealSnapshot,
    required this.recipientName,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailedAddress,
    required this.longitude,
    required this.latitude,
    required this.deliveryTime,
    this.deliveredAt,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory MealDeliveryOrder.fromJson(Map<String, dynamic> json) {
    return MealDeliveryOrder(
      id: json['id'],
      merchantId: json['merchant_id'],
      recipeOrderId: json['recipe_order_id'],
      mealId: json['meal_id'],
      mealSnapshot: json['meal_snapshot'] ?? {},
      recipientName: json['recipient_name'],
      phone: json['phone'],
      province: json['province'],
      city: json['city'],
      district: json['district'],
      detailedAddress: json['detailed_address'],
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      deliveryTime: DateTime.parse(json['delivery_time']),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
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
    if (recipeOrderId != null) {
      json['recipe_order_id'] = recipeOrderId;
    }
    if (mealId != null) {
      json['meal_id'] = mealId;
    }
    json['meal_snapshot'] = mealSnapshot;
    json['recipient_name'] = recipientName;
    json['phone'] = phone;
    json['province'] = province;
    json['city'] = city;
    json['district'] = district;
    json['detailed_address'] = detailedAddress;
    json['longitude'] = longitude;
    json['latitude'] = latitude;
    json['delivery_time'] = deliveryTime.toIso8601String();
    if (deliveredAt != null) {
      json['delivered_at'] = deliveredAt?.toIso8601String();
    }
    if (status != null) {
      json['status'] = status;
    }
    if (createdAt != null) {
      json['created_at'] = createdAt?.toIso8601String();
    }
    if (updatedAt != null) {
      json['updated_at'] = updatedAt?.toIso8601String();
    }
    return json;
  }

  MealDeliveryOrder copyWith({
    String? id,
    String? merchantId,
    String? recipeOrderId,
    String? mealId,
    Map<String, dynamic>? mealSnapshot,
    String? recipientName,
    String? phone,
    String? province,
    String? city,
    String? district,
    String? detailedAddress,
    double? longitude,
    double? latitude,
    DateTime? deliveryTime,
    DateTime? deliveredAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealDeliveryOrder(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      recipeOrderId: recipeOrderId ?? this.recipeOrderId,
      mealId: mealId ?? this.mealId,
      mealSnapshot: mealSnapshot ?? this.mealSnapshot,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      detailedAddress: detailedAddress ?? this.detailedAddress,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
