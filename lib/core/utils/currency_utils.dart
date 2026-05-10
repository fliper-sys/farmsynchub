import 'package:intl/intl.dart';

/// Utility functions for currency formatting and calculations.
abstract final class CurrencyUtils {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'NGN ',
    decimalDigits: 2,
    locale: 'en_NG',
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    symbol: 'NGN ',
    decimalDigits: 1,
  );

  /// Formats a double amount to Nigerian currency format.
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Formats a double amount to compact currency format.
  static String formatCompactCurrency(double amount) {
    return _compactFormat.format(amount);
  }

  /// Parses a currency string back to double.
  static double parseCurrency(String currencyString) {
    final String cleaned = currencyString.replaceAll('NGN', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Calculates percentage change between two values.
  static double calculatePercentageChange(double oldValue, double newValue) {
    if (oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  /// Formats percentage with appropriate sign.
  static String formatPercentage(double percentage) {
    final String formatted = '${percentage.abs().toStringAsFixed(1)}%';
    return percentage >= 0 ? '+$formatted' : '-$formatted';
  }

  /// Rounds a double to specified decimal places.
  static double roundToDecimal(double value, int decimals) {
    final double factor = pow(10, decimals);
    return (value * factor).round() / factor;
  }

  /// Calculates total from a list of amounts.
  static double calculateTotal(List<double> amounts) {
    return amounts.fold(0, (double sum, double amount) => sum + amount);
  }

  /// Calculates balance (income - expenses).
  static double calculateBalance(double income, double expenses) {
    return income - expenses;
  }
}

/// Helper function for power calculation.
double pow(double base, int exponent) {
  double result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
