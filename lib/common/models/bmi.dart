enum BMI {
  underweight(0, 18.5, "偏瘦"),
  normalWeight(18.5, 24.0, "正常"),
  overweight(24.0, 28.0, "超重"),
  obesity(28.0, double.infinity, "肥胖");

  final double lowerBound;
  final double upperBound;
  final String description;

  const BMI(this.lowerBound, this.upperBound, this.description);

  static BMI? fromValue(double? value) {
    if (value == null) return null;
    if (value >= BMI.underweight.lowerBound &&
        value < BMI.underweight.upperBound) {
      return BMI.underweight;
    }
    if (value >= BMI.normalWeight.lowerBound &&
        value < BMI.normalWeight.upperBound) {
      return BMI.normalWeight;
    }
    if (value >= BMI.overweight.lowerBound &&
        value < BMI.overweight.upperBound) {
      return BMI.overweight;
    }
    if (value >= BMI.obesity.lowerBound && value < BMI.obesity.upperBound) {
      return BMI.obesity;
    }
    return null;
  }
}
