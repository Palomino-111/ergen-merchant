import 'dart:ui';
import 'package:flutter/material.dart';
import '../dimensions.dart';

class BottomBarScaffold extends StatelessWidget {
  final Widget? child;

  const BottomBarScaffold({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(
        Dimensions.margin16,
      ),
      // 这个组件是给 Scaffold.bottomNavigationBar 用的，Scaffold 自己会把它贴在底部，
      // 所以这里不能再套 Positioned（没有 Stack 祖先，debug 下会抛 Incorrect use of ParentDataWidget）
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          Dimensions.borderRadius12,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            // 背景色，在没有模糊背景时保证能够跟背景区别开
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            child: child,
          ),
        ),
      ),
    );
  }
}
