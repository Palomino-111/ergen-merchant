import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import '../../../main.dart';
import '../../models/gender.dart';
import '../../models/physical_activity_level.dart';
import '../../models/user_metadata.dart';

class AccountController extends GetxController {
  static AccountController get to => Get.find();

  Rxn<Session> session = Rxn();
  Rxn<User> user = Rxn();
  Rxn<UserMetadata> userMetadata = Rxn();

  void listenToAuthChanges() {
    // 监听Supabase Auth相关的事件
    supabase.auth.onAuthStateChange.listen((authState) async {
      final AuthChangeEvent event = authState.event;
      print('auth, event: $event, session: ${authState.session}');
      session.value = authState.session;
      user.value = authState.session?.user;
      // 更新userMetadata
      Map<String, dynamic>? userMetadataMap =
          authState.session?.user.userMetadata;
      userMetadata.value =
          userMetadataMap != null ? UserMetadata.parse(userMetadataMap) : null;
      await MerchantController.to.onAuthStateChange(authState);
    });
  }

  // TODO 优化1. 这个方法可以再优化，例如可以把入参改成[UserMetadata]，然后给[UserMetadata]加上一个判断数据是否有变化的方法，如果有变化则请求服务器，没有则不请求
  // TODO 优化2. 可以把例如Gender这样的元数据字段都抽象出一个接口，接口包含一个检查接口，检查数据是否合法，是否与原来的数据一样之类的
  // TODO 优化3. 可以把每个字段单独增加一个用于更新的方法，既可以单独更新某个字段，也可以多个字段一起更新，这个用于更新的方法就可以放到TODO 2中的接口中，或者新增一个接口
  // TODO 优化4. 可以做缓存，更新数据后不要那么快的就请求服务器，而是等多个字段都更新后，退出某个界面时统一更新，或者通过其它方式做懒更新，减小服务器压力
  // 更新用户元数据
  // 返回值表示是否更新成功
  Future<bool> updateUserMetadata({
    Gender? gender,
    // todo 后续把生日统一改成Iso8601String格式
    int? birthday,
    double? height,
    double? weight,
    PhysicalActivityLevel? physicalActivityLevel,
  }) async {
    Map newUserMetadata = {};
    // 性别
    if (gender != null) {
      Gender? oldGender = userMetadata.value?.gender;
      if (oldGender != gender) {
        newUserMetadata[UserMetadataKeys.gender] = gender.key;
      }
    }
    // 生日
    if (birthday != null) {
      int? oldBirthday = userMetadata.value?.birthday?.millisecondsSinceEpoch;
      if (oldBirthday != birthday) {
        newUserMetadata[UserMetadataKeys.birthday] = birthday;
      }
    }
    // 身高
    double? newHeight = null;
    if (height != null && height > 0) {
      double? oldHeight = userMetadata.value?.height;
      if (oldHeight != height) {
        newUserMetadata[UserMetadataKeys.height] = height;
        newHeight = height;
      }
    }
    // 体重
    double? newWeight = null;
    if (weight != null && weight > 0) {
      double? oldWeight = userMetadata.value?.weight;
      if (oldWeight != weight) {
        newUserMetadata[UserMetadataKeys.weight] = weight;
        newWeight = weight;
      }
    }
    // bmi
    // 体重或身高改变，bmi也要一起改变
    if (newWeight != null || newHeight != null) {
      double? height =
          newHeight != null ? newHeight : userMetadata.value?.height;
      double? weight =
          newWeight != null ? newWeight : userMetadata.value?.weight;
      if (height != null && weight != null && height > 0) {
        // 身高需要除以100，因为身高的单位是厘米，但是计算BMI要的是米
        newUserMetadata[UserMetadataKeys.bmi] = double.parse(
            (weight / (height / 100 * height / 100)).toStringAsFixed(2));
      }
    }
    // 身体活动水平
    if (physicalActivityLevel != null) {
      PhysicalActivityLevel? oldPhysicalActivityLevel =
          userMetadata.value?.physicalActivityLevel;
      if (oldPhysicalActivityLevel != physicalActivityLevel) {
        newUserMetadata[UserMetadataKeys.physicalActivityLevel] =
            physicalActivityLevel.value;
      }
    }
    // 没有用户信息变化，不请求服务器
    if (newUserMetadata.isEmpty) {
      print("updateUserMetadata, userMetadata unchanged");
      return true;
    }
    // 请求服务器，更新用户信息
    UserResponse? userResponse = null;
    try {
      userResponse = await supabase.auth.updateUser(
        UserAttributes(
          data: newUserMetadata,
        ),
      );
      print("updateUserMetadata, success, ${userResponse}");
      return true;
    } catch (t) {
      print("updateUserMetadata, error, $t");
    }
    return false;
  }

  Future<bool> loginWithSMSVerificationCode(
    String phoneNumber,
  ) async {
    try {
      // supabase调用signInWithOtp之后，
      // supabase内部调用对应的auth hook的边缘函数时不会将Header透传，也就导致客户端无法传参数给边缘函数
      // 这导致我们在进行注册登录功能时，auth hook边缘函数无法判断signInWithOtp请求的客户端是否为Release版本
      // 通过signInWithOtp的data字段也是不行的，signInWithOtp的data字段只在第一次调用时会将元数据写入数据库，
      // 后续的调用就不会再更新user_metadata了（增删改都不行），所以也无法作为我们传参的手段，
      // 因此我们要实现测试版本的手机号不发送短信，默认验证码为固定数字，
      // 只能是在边缘函数中获取提前配置好的手机号与对应的验证码字段列表，
      // 如果这次请求的手机号在这个列表中，表明这个这个手机号是内测手机号，那么就不用发送短信，
      // 浪费短信发送次数了，直接输入提前设置好的验证码即可，而且这个列表是有有效期的，
      // 超出有效期这个列表就没了，又需要重新设置。所以这个supabase用起来还是有些缺陷的，
      // 后续看看是否给官方提交各issue改进一下，或者我们自己部署改源码。
      ///
      // 配置内测手机号列表后，auth hook对应的边缘函数都不会被调用，对应的验证码就是生效的。。。所以都不用发送验证码了
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phoneNumber,

        // data字段只在某个手机号第一次调用signInWithOtp或者其他auth相关接口时候会添加对应字段，
        // 后续的调用都不允许增删改了，因此没啥作用
        data: {},
      );
      print("发送成功");
      return true;
    } on AuthException catch (e) {
      print('发送失败: ${e.message}');
    } catch (e) {
      print("发送失败：$e");
    }
    return false;
  }

  Future<bool> verifyOTP(
    String phoneNumber,
    String smsVerificationCode,
  ) async {
    try {
      // ignore: unused_local_variable
      final AuthResponse response =
          await Supabase.instance.client.auth.verifyOTP(
        phone: phoneNumber,
        token: smsVerificationCode,
        type: OtpType.sms,
      );
      print("验证成功");
      return true;
    } on AuthException catch (e) {
      print('验证失败: ${e.message}');
    } catch (e) {
      print('验证失败， 未知错误: $e');
    }
    return false;
  }

  Future<bool> loginWithPassword(
    String phoneNumber,
    String password,
  ) async {
    try {
      // ignore: unused_local_variable
      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithPassword(
        phone: phoneNumber,
        password: password,
      );
      // 登录成功
      print("登录成功");
      return true;
    } catch (e) {
      print("登录失败：$e");
    }
    return false;
  }

  Future<void> logout() async {
    await supabase.auth.signOut(
      scope: SignOutScope.local,
    );
  }

  Future<bool> changePhone(
    String newPhoneNumber,
  ) async {
    try {
      // ignore: unused_local_variable
      UserResponse userResponse = await supabase.auth.updateUser(UserAttributes(
        phone: newPhoneNumber,
      ));
      print('获取验证码成功');
      return true;
    } catch (e) {
      print('获取验证码失败: $e');
    }
    return false;
  }

  Future<bool> verifyOTPOfChangePhone(
    String newPhoneNumber,
    String smsVerificationCode,
  ) async {
    try {
      // ignore: unused_local_variable
      final AuthResponse response =
          await Supabase.instance.client.auth.verifyOTP(
        phone: newPhoneNumber,
        token: smsVerificationCode,
        type: OtpType.phoneChange,
      );
      print("修改成功");
      return true;
    } catch (e) {
      print("修改失败，$e");
    }
    return false;
  }

  Future<bool> changePassword(
    String newPassword,
  ) async {
    try {
      // ignore: unused_local_variable
      UserResponse userResponse = await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
      print('修改成功');
      return true;
    } catch (e) {
      print('修改失败: $e');
      return false;
    }
  }
}
