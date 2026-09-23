import '../utility/common.dart';

class DishSku {
  // sku id
  final String id;

  // sku 名称
  final String name;

  // sku编码
  final String skuCode;

  // sku价格
  final double? price;

  // sku成本价
  final double? costPrice;

  // sku市场价
  final double? marketPrice;

  // sku销量
  final int salesVolume;

  // sku是否可用
  final bool isAvailable;

  // sku的排序顺序
  final int sortOrder;

  // 创建时间
  final DateTime? createdAt;

  // 更新时间
  final DateTime? updatedAt;

  DishSku({
    required this.id,
    required this.name,
    required this.skuCode,
    required this.price,
    required this.costPrice,
    required this.marketPrice,
    required this.salesVolume,
    required this.isAvailable,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DishSku.fromJson(
    Map<String, dynamic> json,
  ) {
    return DishSku(
      id: json['id'],
      name: json['name'],
      skuCode: json['sku_code'],
      price: parseDouble(json['price']),
      costPrice: parseDouble(json['cost_price']),
      marketPrice: parseDouble(json['market_price']),
      salesVolume: json['sales_volume'],
      isAvailable: json['is_available'],
      sortOrder: json['sort_order'],
      // 时间字段在部分历史数据里是 NULL，避免一条脏数据炸掉整单解析
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku_code': skuCode,
      'price': price,
      'cost_price': costPrice,
      'market_price': marketPrice,
      'sales_volume': salesVolume,
      'is_available': isAvailable,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DishSku copyWith({
    String? id,
    String? name,
    String? skuCode,
    double? price,
    double? costPrice,
    double? marketPrice,
    int? salesVolume,
    bool? isAvailable,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DishSku(
      id: id ?? this.id,
      name: name ?? this.name,
      skuCode: skuCode ?? this.skuCode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      marketPrice: marketPrice ?? this.marketPrice,
      salesVolume: salesVolume ?? this.salesVolume,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
