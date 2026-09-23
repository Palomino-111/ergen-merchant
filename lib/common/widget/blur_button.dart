import 'dart:ui';
import 'package:flutter/material.dart';
import '../dimensions.dart';

class BlurButton extends StatelessWidget {
  const BlurButton({
    super.key,
    required this.imageProvider,
    this.backdropFilter,
    required this.child,
  });

  /// 背景图片
  final ImageProvider imageProvider;

  /// 设置模糊效果
  final BackdropFilter? backdropFilter;

  /// 内容
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        Dimensions.borderRadius12,
      ),

      /// IntrinsicWidth 对性能有较大的损耗，后续再看看怎么优化把
      child: IntrinsicWidth(
        stepHeight: 1,
        stepWidth: 0,
        child: Stack(
          children: [
            // 背景图片
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
            // 模糊效果
            backdropFilter ?? defaultBackdropFilter(),
            // 按钮内容
            child,
          ],
        ),
      ),
    );
  }

  BackdropFilter defaultBackdropFilter() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      // filter: buildImageFilter(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), // 背景颜色
        ),
      ),
    );
  }
}
