import 'package:flutter/material.dart';

import '../my_app_scroll_behavior.dart';

class PageScaffold extends Scaffold {
  PageScaffold({
    super.appBar,
    required Widget body,
    // Color backgroundColor = Colors.black,
    super.backgroundColor,
    super.bottomNavigationBar,
    super.extendBody = true,
    super.extendBodyBehindAppBar = true,
  }) : super(
          body: ScrollConfiguration(
            behavior: MyAppScrollBehavior(),
            child: body,
          ),
          // backgroundColor: backgroundColor,
        );
}
