extension StringValidation on String? {
  bool isNullOrEmpty() {
    return this?.isEmpty ?? true;
  }
}
