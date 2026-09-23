import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

ImageFilter buildImageFilter() => ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0);

double? parseDouble(dynamic value) {
  if (value is! num) return null;
  return value.toDouble();
}

int? parseInt(dynamic value) {
  if (value is! int) return null;
  return value;
}

bool isValidPhoneNumber(String phoneNumber) {
  // 暂时先只考虑中国的手机号规则，后续再支持其它国家/地区的
  return new RegExp(r'^1[3-9]\d{9}$').hasMatch(phoneNumber);
}

bool isValidSmsVerificationCode(String smsVerificationCode) {
  return new RegExp(r'^(?:\d{4}|\d{6})$').hasMatch(smsVerificationCode);
}

// 密码长度限制8-32个字符，至少包含一个字母和数字，可以包含各种特殊字符(包括空格)
// SQL注入等安全问题由数据库侧统一处理
bool isValidPassword(String password) {
  return new RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[\S ]{8,32}$').hasMatch(password);
}

Future<void> makePhoneCall(String phoneNumber) async {
  await launchUrl(
    Uri(
      scheme: 'tel',
      path: phoneNumber,
    ),
  );
}
