extension DateTimeExtension on DateTime {
  /**
   * 获取某天的从00:00开始该天经历的毫秒数
   */
  int getMillisecondsSinceMidnight() {
    return hour * 3600000 + minute * 60000 + second * 1000 + millisecond;
  }

  DateTime getMidnight() {
    return DateTime(year, month, day);
  }
}
