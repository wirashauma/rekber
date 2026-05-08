import 'package:equatable/equatable.dart';

/// Transaction domain entity representing an escrow transaction
class TransactionEntity extends Equatable {
  final String id;
  final String txCode;
  final String buyerId;
  final String sellerId;
  final String? productId;
  final int amount;
  final int platformFee;
  final String status;
  final String? description;
  final String? paymentMethod;
  final String? paymentReference;
  final Map<String, dynamic>? metadata;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final DateTime? disputedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  // Joined fields (populated from queries)
  final String? buyerName;
  final String? sellerName;
  final String? buyerAvatar;
  final String? sellerAvatar;
  final String? productName;

  const TransactionEntity({
    required this.id,
    required this.txCode,
    required this.buyerId,
    required this.sellerId,
    this.productId,
    required this.amount,
    required this.platformFee,
    required this.status,
    this.description,
    this.paymentMethod,
    this.paymentReference,
    this.metadata,
    this.paidAt,
    this.shippedAt,
    this.completedAt,
    this.disputedAt,
    this.expiresAt,
    required this.createdAt,
    this.buyerName,
    this.sellerName,
    this.buyerAvatar,
    this.sellerAvatar,
    this.productName,
  });

  /// Total amount buyer pays (amount + platform fee)
  int get totalAmount => amount + platformFee;

  /// Net amount seller receives (amount - platform fee deducted from their side if needed)
  int get sellerReceives => amount - platformFee;

  /// Check if transaction is in a terminal state
  bool get isTerminal =>
      status == 'completed' || status == 'refunded' || status == 'cancelled';

  /// Check if transaction is active (needs action)
  bool get isActive => !isTerminal;

  /// Check if payment has expired
  bool get isExpired =>
      status == 'awaiting_payment' &&
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!);

  @override
  List<Object?> get props => [id, txCode, status, amount];
}
