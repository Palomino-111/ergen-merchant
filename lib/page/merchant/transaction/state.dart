import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';

class TransactionState {
  final scrollController = ScrollController();
  final easyRefreshController = EasyRefreshController(
    controlFinishRefresh: false,
    controlFinishLoad: false,
  );

  TransactionState() {}
}
