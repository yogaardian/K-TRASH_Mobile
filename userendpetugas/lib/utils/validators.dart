class Validators {
  Validators._();

  static bool isRequired(String value) {
    return value.trim().isNotEmpty;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  }

  static bool isValidPassword(String password, [int minLength = 6]) {
    return password.length >= minLength;
  }

  static bool isValidPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return RegExp(r'^\d{10,13}$').hasMatch(digits);
  }

  static bool isValidOtp(String otp) {
    return RegExp(r'^\d{6}$').hasMatch(otp);
  }
}
