// 可以展示的异常，也就是可以直接把message取出来直接展示给用户错误原因的异常，
// 常用于在一个函数，可能会有多重错误情况时，需要展示给用户不同错误原因，
// 如果为每种情况都加一个异常类，然后再调用函数时根据不同异常去展示不同原因那太奢侈了，
// 或者一个函数返回一个类似Map这样的结构，同事携带错误信息和结果，这种函数明显的可读性不高，
// 为了处理这种场景，因此增加了[ShowableException]类
class ShowableException implements Exception {
  final String message;

  ShowableException(this.message);

  @override
  String toString() {
    return "ShowableException: $message";
  }
}
