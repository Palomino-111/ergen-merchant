import 'package:flutter/material.dart';

import '../../dimensions.dart';
import '../../utility/common.dart';

class TextDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<Widget> actions;
  final AlignmentGeometry alignment;

  const TextDialog({
    super.key,
    this.title = "",
    this.content = "",
    this.actions = const <Widget>[],
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        clipBehavior: Clip.hardEdge,
        margin: EdgeInsets.all(Dimensions.margin16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
        ),
        child: BackdropFilter(
          filter: buildImageFilter(),
          child: Container(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Visibility(
                  visible: title.isNotEmpty,
                  child: Container(
                    margin: EdgeInsets.only(
                      left: Dimensions.margin16,
                      top: Dimensions.margin16,
                      right: Dimensions.margin16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${title}",
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: Dimensions.fontSize32,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),

                // 内容
                Visibility(
                  visible: content.isNotEmpty,
                  child: Container(
                    margin: EdgeInsets.only(
                      left: Dimensions.margin16,
                      top: Dimensions.margin16,
                      right: Dimensions.margin16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${content}",
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: Dimensions.fontSize24,
                      ),
                    ),
                  ),
                ),

                // 操作
                Visibility(
                  visible: actions.isNotEmpty,
                  child: Container(
                    margin: EdgeInsets.only(
                      left: Dimensions.margin16,
                      top: Dimensions.margin16,
                      right: Dimensions.margin16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions,
                    ),
                  ),
                ),
                // 底部的padding
                SizedBox(height: Dimensions.padding16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
