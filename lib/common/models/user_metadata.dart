import '../utility/common.dart';
import 'gender.dart';
import 'physical_activity_level.dart';

// 用户元数据键名常量容器
// 禁止实例化，仅通过静态常量访问
abstract class UserMetadataKeys {
  static const String gender = 'gender';
  static const String birthday = 'birthday';
  static const String height = 'height';
  static const String weight = 'weight';
  static const String bmi = 'bmi';
  static const String physicalActivityLevel = 'physical_activity_level';

  // 禁止实例化
  UserMetadataKeys._();
}

class UserMetadata {
  final Gender? gender;
  final DateTime? birthday;
  final double? height;
  final double? weight;
  final double? bmi;
  final PhysicalActivityLevel? physicalActivityLevel;

  const UserMetadata({
    this.gender,
    this.birthday,
    this.height,
    this.weight,
    this.bmi,
    this.physicalActivityLevel,
  });

  // 将原始数据转换为类型安全对象
  static UserMetadata parse(Map<String, dynamic> metadata) {
    return UserMetadata(
      gender: _parseGender(metadata[UserMetadataKeys.gender]),
      birthday: _parseDateTime(metadata[UserMetadataKeys.birthday]),
      height: parseDouble(metadata[UserMetadataKeys.height]),
      weight: parseDouble(metadata[UserMetadataKeys.weight]),
      bmi: parseDouble(metadata[UserMetadataKeys.bmi]),
      physicalActivityLevel: _parsePhysicalActivityLevel(
        metadata[UserMetadataKeys.physicalActivityLevel],
      ),
    );
  }

  static Gender? _parseGender(dynamic value) {
    if (value is! String) return null;
    return Gender.fromKey(value);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  // 将类型安全对象转换为可存储格式
  Map<String, dynamic> toJson() {
    return {
      UserMetadataKeys.gender: gender?.key,
      // todo 后续把生日统一改成Iso8601String格式
      UserMetadataKeys.birthday: birthday?.millisecondsSinceEpoch,
      UserMetadataKeys.height: height,
      UserMetadataKeys.weight: weight,
      UserMetadataKeys.bmi: bmi,
      UserMetadataKeys.physicalActivityLevel: physicalActivityLevel?.value,
    };
  }

  static _parsePhysicalActivityLevel(dynamic value) {
    double? parsePhysicalActivityLevel = parseDouble(value);
    if (parsePhysicalActivityLevel == null) return null;
    return PhysicalActivityLevel.fromValue(parsePhysicalActivityLevel);
  }

  // 年龄计算属性
// int? get age {
//   if (birthday == null) return null;
//   final now = DateTime.now();
//   int years = now.year - birthday!.year;
//   if (now.month < birthday!.month ||
//       (now.month == birthday!.month && now.day < birthday!.day)) {
//     years--;
//   }
//   return years;
// }
}
