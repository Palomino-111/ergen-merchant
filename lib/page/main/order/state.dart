import 'package:easy_refresh/easy_refresh.dart';

class OrderState {
  final easyRefreshController = EasyRefreshController(
    controlFinishRefresh: false,
    controlFinishLoad: false,
  );

  OrderState() {}
}
