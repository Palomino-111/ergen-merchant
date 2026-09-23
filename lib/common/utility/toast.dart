import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import '../dimensions.dart';
import 'common.dart';

showTextToast(
  BuildContext context,
  String text,
) {
  BotToast.showCustomText(
    align: Alignment.center,
    toastBuilder: ((cancelFunc) => Container(
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.all(Dimensions.margin16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
          ),
          child: BackdropFilter(
            filter: buildImageFilter(),
            child: Container(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              padding: EdgeInsets.all(Dimensions.padding16),
              child: Text(
                text,
                style: TextStyle(
                  decoration: TextDecoration.none,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: Dimensions.fontSize32,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        )),
  );
}

// 例子：showTextLoading(context, "☺ 请稍后...");
showTextLoading(
  BuildContext context,
  String text, {
  bool clickClose = false,
  Duration speed = const Duration(milliseconds: 300),
  Duration pause = const Duration(milliseconds: 300),
}) {
  BotToast.showCustomLoading(
    align: Alignment.center,
    toastBuilder: ((cancelFunc) => Container(
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.all(Dimensions.margin16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
          ),
          child: BackdropFilter(
            filter: buildImageFilter(),
            child: Container(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              padding: EdgeInsets.all(Dimensions.padding16),
              child: AnimatedTextKit(
                animatedTexts: [
                  // TODO 这里的动画曲线还是不是很理想，后续自己定制一下吧，例如可以通过定制ColorizeAnimatedText实现那种来回变色的文字动画，或者实现跑马灯文字动画
                  TyperAnimatedText(
                    text,
                    textStyle: TextStyle(
                      fontSize: Dimensions.fontSize32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    speed: speed,
                    curve: Curves.fastEaseInToSlowEaseOut,
                  ),
                  // TypewriterAnimatedText的结尾的cursor会占用8次speed的时间用于闪烁效果，不好用，所以还是改成TyperAnimatedText了，方便控制速度
                  // TypewriterAnimatedText(
                  //   text,
                  //   textStyle: TextStyle(
                  //     fontSize: Dimensions.fontSize32,
                  //     fontWeight: FontWeight.bold,
                  //     color: Theme.of(context).colorScheme.onSurface,
                  //   ),
                  //   speed: speed,
                  //   curve: Curves.fastEaseInToSlowEaseOut,
                  //   cursor: "",
                  // ),
                ],
                pause: pause,
                repeatForever: true,
                stopPauseOnTap: false,
                displayFullTextOnTap: false,
                // controller: myAnimatedTextController,
              ),
            ),
          ),
        )),
    clickClose: clickClose,
  );
}

showPleaseWaitLoading(
  BuildContext context, {
  bool clickClose = false,
}) {
  showTextLoading(
    context,
    "☺ 请稍后...",
    clickClose: clickClose,
    // 动画总用时300 x 8 = 2.4秒，由于用了Curves.fastEaseInToSlowEaseOut的动画曲线，因此效果是快速出现一部分文字，在慢慢出现剩下的，最后可能会有一点点时间看上去是停顿的，要的就是这个效果
    speed: Duration(milliseconds: 300),
    // 两次动画之间间隔1秒时间
    pause: Duration(milliseconds: 1000),
  );
}

closeAllLoading() {
  BotToast.closeAllLoading();
}
