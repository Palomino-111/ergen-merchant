import 'package:flutter/cupertino.dart';

class MyAppScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // return super.buildOverscrollIndicator(context, child, details);
    // 去除水波纹效果，如果想要精细控制或者自定义就再这里去判断平台然后自定义想要的滑动溢出效果
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
