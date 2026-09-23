import 'package:get/get.dart';
import 'package:zheergen_merchant_end/common/getx/controller/merchant_controller.dart';
import 'package:zheergen_merchant_end/common/models/transaction.dart';
import '../../../main.dart';
import '../../exception/showable_exception.dart';

class TransactionController extends GetxController {
  static TransactionController get to => Get.find();
  final RxList<Transaction> transactions = <Transaction>[].obs;

  // 每页数据量
  int pageSize = 20;

  // 当前页码（从 0 开始）
  int currentPage = 0;

  // 是否有更多数据
  bool hasMore = true;

  // todo 按照日期（区间）获取数据，下拉向前拉流水，上拉向后拉流水，先暂时这样吧，后面上线了再慢慢优化
  /**
   * 获取流水列表
   * [isRefresh]，是否是刷新，true表示刷新，清空列表，重新从第一页数据获取，false表示加载下一页数据
   */
  Future<void> fetchTransactions({
    // 是否是刷新 下拉刷新相当于获取第一页数据
    bool isRefresh = false,
  }) async {
    try {
      final merchantId = MerchantController.to.merchant.value?.id;
      if (merchantId == null) throw ShowableException('商家未登录！');

      int newPage = isRefresh ? 0 : currentPage + 1;
      int offset = newPage * pageSize;

      final response = await supabase
          .from('merchant_transaction')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      final result = response.map((e) => Transaction.fromJson(e));

      this.hasMore = result.length >= pageSize;

      if (isRefresh) {
        transactions.assignAll(result);
      } else {
        transactions.addAll(result);
      }

      this.currentPage = newPage;
    } catch (e) {
      print("fetchTransactions, fail, $e");
      throw ShowableException('获取流水失败，未知错误！');
    }
  }
}
