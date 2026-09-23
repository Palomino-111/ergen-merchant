import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'state.dart';

class MainLogic extends GetxController with GetTickerProviderStateMixin {
  late TabController mainTabController;
  late TabController planTabController;

  final MainState state = MainState();

  @override
  void onInit() {
    super.onInit();
    mainTabController = TabController(length: 2, vsync: this);
    planTabController = TabController(length: 2, vsync: this);
  }

  @override
  void onClose() {
    mainTabController.dispose();
    planTabController.dispose();
    super.onClose();
  }
}
