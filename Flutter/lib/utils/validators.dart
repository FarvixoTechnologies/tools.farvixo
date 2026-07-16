/// Input validation rules (see docs/AUTHENTICATION_SYSTEM.md — Validation).
class Validators {
  Validators._();

  static final _emailRe =
      RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[A-Za-z]{2,}$');
  static final _phoneRe = RegExp(r'^\+?[0-9]{7,15}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.replaceAll(RegExp(r'[\s\-()]'), '') ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (!_phoneRe.hasMatch(v)) {
      return 'Enter a valid phone number with country code';
    }
    return null;
  }

  /// Spec: minimum 8 chars, uppercase, lowercase, number, special character.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Add a lowercase letter';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
    if (!v.contains(RegExp(r'[^A-Za-z0-9]'))) return 'Add a special character';
    return null;
  }

  /// Lenient check for sign-in (rules only enforced at registration).
  static String? loginPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Minimum 6 characters';
    return null;
  }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (v.length != 6 || int.tryParse(v) == null) {
      return 'Enter the 6-digit code';
    }
    return null;
  }

  /// 0.0–1.0 strength score for the password strength meter.
  static double passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0.0;
    if (value.length >= 8) score += 0.3;
    if (value.length >= 12) score += 0.1;
    if (value.contains(RegExp(r'[A-Z]'))) score += 0.15;
    if (value.contains(RegExp(r'[a-z]'))) score += 0.15;
    if (value.contains(RegExp(r'[0-9]'))) score += 0.15;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  static String strengthLabel(double strength) {
    if (strength <= 0) return '';
    if (strength < 0.4) return 'Weak';
    if (strength < 0.7) return 'Fair';
    if (strength < 0.9) return 'Good';
    return 'Strong';
  }
}
