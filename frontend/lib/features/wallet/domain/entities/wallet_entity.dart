import 'package:equatable/equatable.dart';

/// Wallet domain entity showing available vs escrow balance
class WalletEntity extends Equatable {
  final String id;
  final String userId;
  final int availableBalance;
  final int escrowBalance;
  final DateTime updatedAt;

  const WalletEntity({
    required this.id,
    required this.userId,
    required this.availableBalance,
    required this.escrowBalance,
    required this.updatedAt,
  });

  /// Total balance (available + escrow)
  int get totalBalance => availableBalance + escrowBalance;

  /// Check if user has enough available balance for withdrawal
  bool canWithdraw(int amount) => availableBalance >= amount;

  @override
  List<Object?> get props => [id, userId, availableBalance, escrowBalance];
}
