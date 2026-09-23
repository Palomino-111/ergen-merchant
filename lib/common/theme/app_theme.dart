import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config.dart';

class AppTheme {
  static MyTheme currentTheme = Get.put(MyTheme());

  static String appName = "折耳根商家端";

  //Colors for theme
  static Color lightPrimary = Color(0xfffcfcff);
  static Color darkPrimary = Colors.black;
  static Color? lightAccent = Colors.blueGrey[900];
  static Color darkAccent = Colors.white;
  static Color lightBG = Color(0xfffcfcff);
  static Color darkBG = Colors.black;
  static Color badgeColor = Colors.red;

  static ThemeData light({
    required BuildContext context,
  }) {
    return ThemeData(
      useMaterial3: false,
      textSelectionTheme: TextSelectionThemeData(
        selectionHandleColor: currentTheme.currentColor(),
        cursorColor: currentTheme.currentColor(),
        selectionColor: currentTheme.currentColor(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(width: 1.5, color: currentTheme.currentColor()),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.0),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
          color: Color(0xfff5f9ff), foregroundColor: Colors.black),
      cardTheme: CardTheme(
        clipBehavior: Clip.antiAlias,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.0),
        ),
      ),
      disabledColor: Colors.grey[600],
      brightness: Brightness.light,
      indicatorColor: currentTheme.currentColor(),
      progressIndicatorTheme: const ProgressIndicatorThemeData()
          .copyWith(color: currentTheme.currentColor()),
      iconTheme: IconThemeData(
        color: Colors.grey[800],
        opacity: 1.0,
        size: 24.0,
      ),
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.grey[800],
            brightness: Brightness.light,
            secondary: currentTheme.currentColor(),
          ),
    );
  }

  static ThemeData dark({
    required BuildContext context,
  }) {
    return ThemeData(
      // 设置暗色模式，表明这个ThemeData是用于dark模式
      brightness: Brightness.dark,
      // 不使用Material3设计语言
      useMaterial3: false,
      // 颜色方案
      colorScheme: _darkColorScheme(context),
      // colorScheme: Theme.of(context).colorScheme.copyWith(
      //   primary: Colors.white,
      //   secondary: currentTheme.currentColor(),
      //   brightness: Brightness.dark,
      // ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          elevation: 0.0,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionHandleColor: currentTheme.currentColor(),
        cursorColor: Colors.blue,
        selectionColor: currentTheme.currentColor(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(width: 1.5, color: currentTheme.currentColor()),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.0),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        color: currentTheme.getCanvasColor(),
        foregroundColor: Colors.white,
      ),
      canvasColor: Colors.black,
      // 待会儿看下怎么设置
      cardColor: null,
      cardTheme: CardTheme(
        color: Colors.grey[800],
        clipBehavior: Clip.antiAlias,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.0),
        ),
      ),
      dialogBackgroundColor: currentTheme.getCardColor(),
      progressIndicatorTheme: const ProgressIndicatorThemeData()
          .copyWith(color: currentTheme.currentColor()),
      iconTheme: const IconThemeData(
        color: Colors.white,
        opacity: 1.0,
        size: 24.0,
      ),
      textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      disabledColor: Colors.grey[600],
      indicatorColor: currentTheme.currentColor(),
    );
  }

  static ColorScheme _darkColorScheme(BuildContext context) {
    // 个人感觉material design的各种命名和整个系统有可取之处，但是整体来说，他们的命名方式并不通用，参考参考就行，颜色/UI，
    // 我们目前折耳根项目只用四个颜色命名就可以了，surface、onSurface、primary、onPrimary
    // 我们这里的surface颜色指的就是平面颜色/背景色，例如页面背景色、卡片背景色、按钮背景色等，
    // onSurface颜色就是放在surface上的颜色，需要与surface形成对比，例如页面背景上的文字颜色、按钮上的文字/图标颜色等，
    // primary就是强调色，可以用于按钮背景，按钮文字等需要强调某部分UI的场景，具体怎么用，具体问题具体分析。
    return ColorScheme(
      // 设置 亮/暗 模式
      brightness: Brightness.dark,

      // 表面与背景色系（Surface & Background）
      // 主要表面背景色（如Scaffold、卡片、对话框等的背景）。
      surface: Colors.black,
      // 表面上的内容色（如常规文字）。
      onSurface: Colors.white,
      // 较暗的表面色（用于需要分层的背景）。
      surfaceDim: null,
      // 较亮的表面色（如浮动元素）。
      surfaceBright: null,
      // 不同层级的表面容器颜色（数值越高，颜色越深/对比度越高）。surfaceContainerLowest → surfaceContainerHighest
      surfaceContainerLowest: null,
      surfaceContainerLow: null,
      // 表面容器的默认颜色
      surfaceContainer: null,
      // 表面容器的高亮度颜色
      surfaceContainerHigh: null,
      // 表面容器的最高亮度颜色
      surfaceContainerHighest: null,
      // 表面上的次要内容色（如副标题、禁用状态文字）。
      onSurfaceVariant: null,

      // 主色系（强调色/品牌色）
      // 主品牌色，用于按钮、重要交互元素（如 FAB）、选中状态等。
      primary: Colors.blue,
      // 主品牌色上的内容色（如文字、图标），与 primary 形成高对比度。
      onPrimary: Colors.white,
      // 主色的容器背景色（如卡片、菜单背景），通常比 primary 更浅或更深。
      primaryContainer: null,
      // 主色容器上的内容色，与 primaryContainer 形成对比。是Material3新定义的，先暂时不用管
      onPrimaryContainer: null,

      // TODO
      // 固定主色（不知道什么意思，后续再看吧）
      primaryFixed: null,

      // 固定主色上的文字颜色（不知道什么意思，后续再看吧）
      onPrimaryFixed: null,
      // 固定主色的变体上的文字颜色（不知道什么意思，后续再看吧）
      onPrimaryFixedVariant: null,
      // 固定主色的暗色版本（不知道什么意思，后续再看吧）
      primaryFixedDim: null,

      // 次级色系，暂时不用
      // 次要品牌色，用于次级按钮、进度条、滑块等。
      secondary: Colors.transparent,
      // 次要色上的内容色（如文字、图标）。
      onSecondary: Colors.transparent,
      // 次要色的容器背景色（如次级卡片）。（是Material3新定义的，先暂时不用管）
      secondaryContainer: null,
      // 次要色容器上的内容色。（是Material3新定义的，先暂时不用管）
      onSecondaryContainer: null,

      // TODO
      // 固定次级色（不知道什么意思，后续再看吧）
      secondaryFixed: null,
      // 固定次级色的暗色版本（不知道什么意思，后续再看吧）
      secondaryFixedDim: null,
      // 固定次级色上的文字颜色（不知道什么意思，后续再看吧）
      onSecondaryFixed: null,
      // 固定次级色的变体上的文字颜色（不知道什么意思，后续再看吧）
      onSecondaryFixedVariant: null,

      // 三级色系
      // ...略

      // 错误色系
      // 错误状态色（如输入框错误提示）。
      error: Colors.redAccent,
      // 错误色上的内容色（如错误提示文字）。
      onError: Colors.white,
      // 错误容器背景色（如错误提示区域）。
      errorContainer: null,
      // 错误容器上的内容色。
      onErrorContainer: null,

      // 其它
      // 轮廓色（如输入框边框、分割线）。
      outline: null,
      // 次要轮廓色（如更淡的分割线）。
      outlineVariant: null,
      // 阴影色（用于元素的投影）。
      shadow: null,
      // 遮罩色（如底部导航栏上方的遮罩）。
      scrim: null,

      // 反色与特殊效果（Inverse & Effects）
      // 反色表面（用于高对比度场景）。
      inverseSurface: null,
      // 反色表面上的内容色。
      onInverseSurface: null,
      // 主色的反色版本（用于反色表面的交互元素）。
      inversePrimary: null,
      // 表面着色（用于给表面添加主色色调）。
      surfaceTint: null,
    );
    // return Theme.of(context).colorScheme.copyWith(
    //       primary: Colors.white,
    //       secondary: currentTheme.currentColor(),
    //       brightness: Brightness.dark,
    //     );
  }
}
