import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum PhysicalActivityLevel {
  // TODO 那种不运动的，休息的人群该用什么等级？例如主播、生病在家静养的。
  // 低强度身体活动水平
  PAL1_4("PAL1_4", 1.4),
  // 中等强度身体活动水平
  PAL1_7("PAL1_7", 1.7),
  // 高强度身体活动水平
  PAL2_0("PAL2_0", 2.0);

  final String key;
  final double value;

  /**
   * 身体活动水平
   * [key] 身体活动强度的key，表示等级，1_4表示1.4，指的就是PAL系数，由于不同标准对不同等级的身体强度定义有区别，因此直接通过这样的方式来命名，方便后续扩展
   * [value] 身体活动强度系数
   */
  const PhysicalActivityLevel(
    this.key,
    this.value,
  );

  static PhysicalActivityLevel? fromKey(String? key) {
    if (key == null) return null;
    try {
      return PhysicalActivityLevel.values
          .firstWhere((value) => value.key == key);
    } catch (e) {
      print("PhysicalActivityLevel.fromKey, $e");
    }
    return null;
  }

  static PhysicalActivityLevel? fromValue(double? value) {
    if (value == null) return null;
    try {
      return PhysicalActivityLevel.values.firstWhere(
          (physicalActivityLevel) => physicalActivityLevel.value == value);
    } catch (e) {
      print("PhysicalActivityLevel.fromValue, $e");
    }
    return null;
  }
}

// 扩展枚举的本地化
extension PhysicalActivityLevelLocalization on PhysicalActivityLevel {
  String? localized(BuildContext context) {
    switch (this) {
      case PhysicalActivityLevel.PAL1_4:
        return AppLocalizations.of(context)?.lowIntensity;
      case PhysicalActivityLevel.PAL1_7:
        return AppLocalizations.of(context)?.mediumIntensity;
      case PhysicalActivityLevel.PAL2_0:
        return AppLocalizations.of(context)?.highIntensity;
    }
  }

  String? description(BuildContext context) {
    // todo 文本国际化
    switch (this) {
      case PhysicalActivityLevel.PAL1_4:
        return "低强度：一般指以静态或坐位工作生活方式为主的人员。很少或没有重体力的休闲活动，如健身、篮球、羽毛球等体育活动。"
            "\n常见人群：办公室职员、互联网行业产研人员、科技行业产研人员、金融行业从业者等。";
      // return AppLocalizations.of(context)?.lowIntensity;
      case PhysicalActivityLevel.PAL1_7:
        return "中等强度：一般指以站着或走着工作生活方式为主的人员。很少或没有重体力的休闲活动，如健身、篮球、羽毛球等体育活动。"
            "\n常见人群：家庭主妇、销售人员、有健身或运动习惯的互联网行业产研人员等。";
      // return AppLocalizations.of(context)?.mediumIntensity;
      case PhysicalActivityLevel.PAL2_0:
        return "高强度：一般指重体力工作职业或重体力休闲活动方式人员。"
            "\n常见人群：建筑工人、农民、矿工、运动员等。";
      // return AppLocalizations.of(context)?.highIntensity;
    }
  }
}
