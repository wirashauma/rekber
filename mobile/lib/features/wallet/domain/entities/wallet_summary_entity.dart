import 'package:equatable/equatable.dart';

class WalletSummaryEntity extends Equatable {
  final int balance;
  final int heldBalance;

  const WalletSummaryEntity({
    required this.balance,
    required this.heldBalance,
  });

  int get totalBalance => balance + heldBalance;

  @override
  List<Object?> get props => [balance, heldBalance];
}

class WalletSummaryModel extends WalletSummaryEntity {
  const WalletSummaryModel({
    required super.balance,
    required super.heldBalance,
  });

  factory WalletSummaryModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    return WalletSummaryModel(
      balance: parseInt(json['balance']),
      heldBalance: parseInt(json['heldBalance'] ?? json['held_balance']),
    );
  }
}
