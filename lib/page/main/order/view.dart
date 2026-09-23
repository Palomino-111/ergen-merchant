import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/widget/page_scaffold.dart';
import '../../../common/dimensions.dart';
import 'logic.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);

  @override
  HomeState createState() => HomeState();
}

class HomeState extends State<OrderPage> with AutomaticKeepAliveClientMixin {
  final logic = Get.put(OrderLogic());
  final state = Get.find<OrderLogic>().state;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GetBuilder<OrderLogic>(
      assignId: true,
      builder: (logic) {
        return PageScaffold(
          body: Column(
            children: [
              Expanded(
                child: Text(
                  "订单",
                  style: TextStyle(
                    fontSize: Dimensions.fontSize32,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
