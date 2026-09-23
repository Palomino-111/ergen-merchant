import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zheergen_merchant_end/common/getx/controller/meal_delivery_order_controller/awaiting_preparation_meal_delivery_order_controller.dart';
import 'package:zheergen_merchant_end/common/getx/controller/transaction_controller.dart';
import 'package:zheergen_merchant_end/page/main/view.dart';
import 'package:zheergen_merchant_end/page/sign_agreement/view.dart';
import 'package:bot_toast/bot_toast.dart';
import 'common/dependency_injection/binding.dart';
import 'common/easy_refresh/utility.dart';
import 'common/env.dart';
import 'common/getx/controller/account_controller.dart';
import 'common/getx/controller/meal_delivery_order_controller/all_meal_delivery_order_controller.dart';
import 'common/getx/controller/merchant_controller.dart';
import 'common/hive_names.dart';
import 'common/theme/app_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'common/utility/common.dart';

/// 调试用 HTTP 代理：dart:io 默认直连、不走系统代理，
/// 国内直连 supabase.co 时请求会一直挂着（表现就是「一直在加载」）。
/// 通过 `--dart-define=HTTP_PROXY=host:port` 打开。
class _DebugHttpOverrides extends HttpOverrides {
  _DebugHttpOverrides(this.proxy);

  final String proxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) => 'PROXY $proxy';
    return client;
  }
}

Future<void> main() async {
  if (Env.httpProxy.isNotEmpty) {
    print('使用调试代理: ${Env.httpProxy}');
    HttpOverrides.global = _DebugHttpOverrides(Env.httpProxy);
  }
  await initializeBeforeRunApp();
  runApp(const MyApp());
}

Future<void> initializeBeforeRunApp() async {
  await initHive();
  // TODO 临时（调试期）：协议签署页的「同意/不同意」按钮因为
  //  colorScheme.secondary 是透明色而看不见，先无条件视为已签署，直接进主页。
  //  协议页修好后删掉这一行即可恢复原来的「先签协议」流程。
  await Hive.box(HiveNames.settings)
      .put('userHasSignedTheRelevantAgreement', true);
  initGetX();
  await initSupabase();
  await initFluwx();
}

final Fluwx fluwx = Fluwx();

Future<void> initFluwx() async {
  // final isSuccess = await fluwx.registerApi(
  //   // todo 微信公众平台生成的这个id没有区分测试版本和线上版，上线后需要用线上版本的app重新生成一次这个id，具体怎么生成可以看微信开发平台的后台文档
  //   appId: "wxce221bbab2d2c35f",
  //   // todo 通联支付ios需要增加这个链接才能调起好像，后面适配ios的时候记得重新看文档弄一下
  //   // universalLink: "https://your.univerallink.com/link/",
  // );
  // print("initFluwx, isSuccess:$isSuccess");
}

void initGetX() {
  RepositoryBinding().dependencies();
  Get.put(AccountController());
  Get.put(MerchantController());
  Get.put(TransactionController());
  Get.put(AllMealDeliveryOrderController());
  Get.put(AwaitingPreparationMealDeliveryOrderController());
  // Get.put(AddressController());
  // Get.put(RecipeController());
  // Get.put(AllRecipeOrderController());
  // Get.put(ActiveRecipeOrderController());
}

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  // 初始化Supabase（地址与 key 可以用 --dart-define 覆盖，见 common/env.dart）
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  // 执行那些依赖supabase初始化的操作
  AccountController.to.listenToAuthChanges();
}

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox(HiveNames.settings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    initEasyRefresh(context);

    // 用户需要先签署相关协议才能使用APP（《用户协议》与《隐私政策》）
    bool userHasSignedTheRelevantAgreement = Hive.box(HiveNames.settings)
        .get('userHasSignedTheRelevantAgreement', defaultValue: false);
    Widget home =
        userHasSignedTheRelevantAgreement ? MainPage() : SignAgreementPage();

    return GetMaterialApp(
      title: AppTheme.appName,
      theme: AppTheme.dark(context: context),
      darkTheme: AppTheme.dark(context: context),
      home: home,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // 初始化BotToastInit
        final botToastBuilder = BotToastInit();
        final botToastTree = botToastBuilder(context, child);
        return Stack(
          children: [
            botToastTree,
            // 状态栏背景
            ClipRect(
              child: BackdropFilter(
                filter: buildImageFilter(),
                child: Container(
                  height: MediaQuery.of(context).padding.top,
                ),
              ),
            ),
          ],
        );
      },
      navigatorObservers: [BotToastNavigatorObserver()],
    );
  }
}
