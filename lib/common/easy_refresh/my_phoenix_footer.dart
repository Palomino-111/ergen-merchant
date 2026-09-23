import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import '../dimensions.dart';
import 'styles/phoenix/phoenix_indicator.dart';

// 为了实现Footer与Content之间有16dp的padding，只能先这样做了，目前没有其它更好的办法，最好的方式是改EasyRefresh，不过太麻烦了，后续再说吧
class MyPhoenixFooter extends PhoenixFooter {
  final EdgeInsetsGeometry? margin;

  MyPhoenixFooter(
    BuildContext context, {
    this.margin,
    super.position,
    super.triggerOffset,
    super.safeArea = false,
  }) : super(
          skyColor: Theme.of(context).colorScheme.primary,
        );

  @override
  Widget build(BuildContext context, IndicatorState state) {
    assert(state.axis == Axis.vertical,
        'PhoenixFooter does not support horizontal scrolling.');
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.borderRadius12),
      ),
      clipBehavior: Clip.hardEdge,
      child: PhoenixIndicator(
        key: key,
        state: state,
        reverse: state.reverse,
        skyColor: skyColor,
      ),
    );
  }
}
