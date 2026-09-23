import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum Gender {
  male("male"),
  female("female");

  final String key;

  const Gender(this.key);

  static Gender? fromKey(String? key) {
    if (key == null) return null;
    try {
      return Gender.values.firstWhere((status) => status.key == key);
    } catch (e) {
      print("Gender.fromKey, $e");
    }
    return null;
  }
}

// 扩展枚举的本地化
extension GenderLocalization on Gender {
  String? localized(BuildContext context) {
    switch (this) {
      case Gender.male:
        return AppLocalizations.of(context)?.male;
      case Gender.female:
        return AppLocalizations.of(context)?.female;
    }
  }
}
