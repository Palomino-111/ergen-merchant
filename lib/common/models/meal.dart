import '../utility/common.dart';
import 'dish_sku.dart';

class Meal {
  final String id;
  final String name;
  final String? description;

  // 用餐起始时间（毫秒级时间戳），是一个从0开始的毫秒级时间戳相对"0"的偏移量，
  // 表示了用餐顺序（第N餐、第N天），用餐时间（时分秒）、用餐时间间隔等，
  // 是一个简洁通用好扩展的设计方式，允许时间重叠，有可能一餐要吃多餐之类的，
  // 或者一餐是给不同人吃之类的（家庭场景）。
  // 例如：
  // startTime = 0，表示第一天的凌晨00:00分用餐，
  // startTime = 28800000，表示第一天的早上08:00用餐
  // startTime = 115200000，表示第二天的早上08:00用餐
  final int startTime;
  List<DishSku> dishSkus = []; // 直接关联菜品（按sort_order排序）

  Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.startTime,
  });

  factory Meal.fromJson(
    Map<String, dynamic> json,
  ) {
    return Meal(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      startTime: parseInt(json['start_time']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_time': startTime,
    };
  }

  Meal copyWith({
    String? id,
    String? name,
    String? description,
    int? startTime,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
    );
  }
}
