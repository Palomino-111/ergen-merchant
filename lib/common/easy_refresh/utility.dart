import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/widgets.dart';
import 'my_phoenix_footer.dart';
import 'my_phoenix_header.dart';

void initEasyRefresh(BuildContext context) {
  EasyRefresh.defaultHeaderBuilder = () => MyPhoenixHeader(context);
  EasyRefresh.defaultFooterBuilder = () => MyPhoenixFooter(context);
}
