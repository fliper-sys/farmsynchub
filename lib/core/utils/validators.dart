/// Validation utility functions for form inputs.
abstract final class Validators {
  /// Validates that a string is not empty.
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validates email format.
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates Nigerian phone number format.
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove spaces, hyphens, and parentheses
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check for Nigerian phone number patterns
    final phoneRegex = RegExp(r'^(?:\+234|0)[789]\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid Nigerian phone number';
    }
    return null;
  }

  /// Validates positive number.
  static String? positiveNumber(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;

    final number = double.tryParse(value);
    if (number == null) {
      return '${fieldName ?? 'Value'} must be a valid number';
    }
    if (number <= 0) {
      return '${fieldName ?? 'Value'} must be greater than 0';
    }
    return null;
  }

  /// Validates farm size (0.1 to 10 hectares).
  static String? farmSize(String? value) {
    if (value == null || value.isEmpty) return null;

    final size = double.tryParse(value);
    if (size == null) {
      return 'Farm size must be a valid number';
    }
    if (size < 0.1 || size > 10) {
      return 'Farm size must be between 0.1 and 10 hectares';
    }
    return null;
  }

  /// Validates crop area planted.
  static String? cropArea(String? value) {
    if (value == null || value.isEmpty) return null;

    final area = double.tryParse(value);
    if (area == null) {
      return 'Area must be a valid number';
    }
    if (area <= 0) {
      return 'Area must be greater than 0';
    }
    return null;
  }

  /// Validates livestock count.
  static String? livestockCount(String? value) {
    if (value == null || value.isEmpty) return null;

    final count = int.tryParse(value);
    if (count == null) {
      return 'Count must be a valid number';
    }
    if (count < 0) {
      return 'Count cannot be negative';
    }
    return null;
  }

  /// Validates monetary amount.
  static String? amount(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove currency symbol and commas for parsing
    final cleaned = value.replaceAll('₦', '').replaceAll(',', '').trim();
    final amount = double.tryParse(cleaned);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount < 0) {
      return 'Amount cannot be negative';
    }
    return null;
  }

  /// Validates minimum length.
  static String? minLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.length < minLength) {
      return '${fieldName ?? 'Field'} must be at least $minLength characters';
    }
    return null;
  }

  /// Validates maximum length.
  static String? maxLength(String? value, int maxLength, {String? fieldName}) {
    if (value != null && value.length > maxLength) {
      return '${fieldName ?? 'Field'} must not exceed $maxLength characters';
    }
    return null;
  }

  /// Combines multiple validators.
  static String? combine(List<String? Function(String?)> validators, String? value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}