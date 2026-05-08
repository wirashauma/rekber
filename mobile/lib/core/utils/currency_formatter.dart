import 'package:intl/intl.dart';

/// Currency formatting utility for IDR (Indonesian Rupiah)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Format amount to full IDR: Rp1.500.000
  static String format(int amount) => _idrFormat.format(amount);

  /// Format amount to compact IDR: Rp1,5jt
  static String formatCompact(int amount) => _compactFormat.format(amount);

  /// Format amount without symbol: 1.500.000
  static String formatNoSymbol(int amount) {
    return NumberFormat('#,##0', 'id_ID').format(amount);
  }

  /// Parse formatted string back to int
  static int parse(String formatted) {
    final cleaned = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
}
