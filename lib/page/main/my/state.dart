import 'package:get/get.dart';

class MyState {
  // 身高（单位厘米），0.0表示未设置，后续国际化时再考虑单位问题
  RxDouble height = 0.0.obs;

  // 体重（Kg），0.0表示未设置，后续国际化时再考虑单位问题
  RxDouble weight = 0.0.obs;

  // BMI，公式：BMI = 体重（kg）/身高（m）²，通过身高和体重计算即可，不需要额外存储
  RxString bmi = "0.0".obs;

  /**
   * [height] 身高，单位：米
   * [weight] 体重，单位：千克
   */
  void calculateAndUpdateBMI(double height, double weight) {
    // 分母不能为0
    if (height == 0) {
      return;
    }
    bmi.value = (weight / (height * height)).toStringAsFixed(2);
  }

  // late AccountEntity accountInfo;
  MyState() {
    // BMI
    ever(
      height,
      (value) {
        calculateAndUpdateBMI(value / 100, weight.value);
      },
    );
    ever(
      weight,
      (value) {
        calculateAndUpdateBMI(height.value / 100, value);
      },
    );
  }
}
