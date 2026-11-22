import 'package:equatable/equatable.dart';

class PublicConfigModel extends Equatable {
  final double feePercent;
  final int feeMin;
  final String feePayerDefault;
  final int withdrawMin;
  final int withdrawFee;
  final int maxTransactionAmount;

  const PublicConfigModel({
    required this.feePercent,
    required this.feeMin,
    required this.feePayerDefault,
    required this.withdrawMin,
    required this.withdrawFee,
    required this.maxTransactionAmount,
  });

  factory PublicConfigModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    return PublicConfigModel(
      feePercent: parseDouble(json['fee_percent'], 0.02),
      feeMin: parseInt(json['fee_min'], 1000),
      feePayerDefault: json['fee_payer_default']?.toString() ?? 'SPLIT',
      withdrawMin: parseInt(json['withdraw_min'], 50000),
      withdrawFee: parseInt(json['withdraw_fee'], 0),
      maxTransactionAmount: parseInt(json['max_transaction_amount'], 5000000),
    );
  }

  /// Calculates platform fee based on amount and config
  int calculateFee(int amount) {
    final rawFee = (amount * feePercent).ceil();
    return rawFee < feeMin ? feeMin : rawFee;
  }

  @override
  List<Object?> get props => [
        feePercent,
        feeMin,
        feePayerDefault,
        withdrawMin,
        withdrawFee,
        maxTransactionAmount,
      ];
}
