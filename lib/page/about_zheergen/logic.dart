import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'state.dart';

class AboutZheergenLogic extends GetxController {
  final AboutZheergenState state = AboutZheergenState();

  @override
  Future<void> onInit() async {
    super.onInit();
    state.packageInfo.value = await PackageInfo.fromPlatform();
  }
}
