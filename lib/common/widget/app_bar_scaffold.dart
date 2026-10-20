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
                          child: Container(
                            alignment: Alignment.center,
                            height: Dimensions.button60,
                            padding: EdgeInsets.only(
                              left: Dimensions.padding16,
                              right: Dimensions.padding16,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Dimensions.borderRadius12,
                              ),
                              // 原来是 sigma 10 的 BackdropFilter：标题条同样压在
                              // 滚动内容上（PageScaffold 开了 extendBodyBehindAppBar），
                              // 每帧都要重算一次全宽模糊。换成 80% 黑的半透明块，
                              // 暗色主题下观感几乎一致，滚动时不再产生离屏层。
                              // 想调通透程度就改这里的 alpha（0xCC = 80%）。
                              color: const Color(0xCC000000),
                            ),
                            child: Text(
                              titleString,
                              style: TextStyle(
                                fontSize: Dimensions.fontSize32,
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
