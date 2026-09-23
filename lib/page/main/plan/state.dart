import 'package:easy_refresh/easy_refresh.dart';

class PlanState {
  final awaitingPreparationEasyRefreshController = EasyRefreshController(
    controlFinishRefresh: false,
    controlFinishLoad: false,
  );
  final allEasyRefreshController = EasyRefreshController(
    controlFinishRefresh: false,
    controlFinishLoad: false,
  );

  PlanState() {}
}
