import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../dimensions.dart';

class AppBarScaffold extends AppBar {
  static const double appBarHeight =
      Dimensions.button60 + Dimensions.margin16 * 2;

  AppBarScaffold({
    SystemUiOverlayStyle? systemOverlayStyle,
    super.backgroundColor = Colors.transparent,
    super.toolbarHeight = appBarHeight,
    super.elevation = 0,
    super.titleSpacing = 0,
    super.leadingWidth = Dimensions.button60 + Dimensions.margin16,
    Widget? leading,
    Widget? title,
    String? titleString,
    List<Widget>? actions,
  }) : super(
          systemOverlayStyle: systemOverlayStyle ??
              SystemUiOverlayStyle(
                // 透明状态栏
                statusBarColor: Colors.transparent,

                // 状态栏图标颜色为暗色
                statusBarIconBrightness: Brightness.light,
              ),
          leading: leading ??
              Row(
                children: [
                  SizedBox(
                    width: Dimensions.margin16,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.borderRadius12,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: CupertinoButton(
                        borderRadius: BorderRadius.all(
                          Radius.circular(Dimensions.borderRadius12),
                        ),
                        color: Colors.white.withOpacity(0.1),
                        minSize: Dimensions.button60,
                        padding: EdgeInsets.zero,
                        child: Icon(
                          Icons.arrow_back,
                          size: Dimensions.iconSize32,
                        ),
                        onPressed: () => Get.back(),
                      ),
                    ),
                  ),
                ],
              ),
          title: title != null
              ? title
              : titleString == null
                  ? SizedBox()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: Dimensions.padding16,
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Dimensions.borderRadius12,
                            ),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    Dimensions.borderRadius12),
                                child: Container(
                                  // color: Colors.white.withOpacity(0.1),
                                  // color: t1.value
                                  //     ? Colors.red.withOpacity(0.1)
                                  //     : Theme.of(context).cardColor,
                                  // color: Theme.of(context).cardColor,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.only(
                                    left: Dimensions.padding16,
                                    right: Dimensions.padding16,
                                  ),
                                  height: Dimensions.button60,
                                  child: Text(
                                    "${titleString ?? ""}",
                                    style: TextStyle(
                                      fontSize: Dimensions.fontSize32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          actions: [
            Row(
              children: [
                if (actions != null)
                  ...actions
                else
                  SizedBox(
                    width: Dimensions.button60,
                  ),
                SizedBox(
                  width: Dimensions.margin16,
                ),
              ],
            ),
          ],
        );
}
