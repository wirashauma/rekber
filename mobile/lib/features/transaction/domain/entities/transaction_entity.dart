import 'package:equatable/equatable.dart';

/// Transaction domain entity representing an escrow transaction
class TransactionEntity extends Equatable {
  final String id;
  final String txCode;
  final String buyerId;
  final String sellerId;
  final int amount;
  final int platformFee;
  final int buyerFee;
  final int sellerFee;
  final String feePayer;
  final String status;
  final String? description;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? refundedAt;
  final DateTime? disputedAt;
  final DateTime? autoReleaseAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String? courier;
  final String? trackingNumber;
  final String? shipmentNote;
  final List<String> shipmentProofUrls;

  // Joined user fields
  final String? buyerName;
  final String? sellerName;
  final String? buyerEmail;
  final String? sellerEmail;
  final String? buyerAvatar;
  final String? sellerAvatar;

  const TransactionEntity({
    required this.id,
    required this.txCode,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    required this.platformFee,
    this.buyerFee = 0,
    this.sellerFee = 0,
    this.feePayer = 'SPLIT',
    required this.status,
    this.description,
    this.paidAt,
    this.shippedAt,
    this.completedAt,
    this.cancelledAt,
    this.refundedAt,
    this.disputedAt,
    this.autoReleaseAt,
    this.expiresAt,
    required this.createdAt,
    this.courier,
    this.trackingNumber,
    this.shipmentNote,
    this.shipmentProofUrls = const [],
    this.buyerName,
    this.sellerName,
    this.buyerEmail,
    this.sellerEmail,
    this.buyerAvatar,
    this.sellerAvatar,
  });

  /// Total amount buyer must pay (price + buyer-borne fee)
  int get totalAmount => amount + buyerFee;

  /// Net amount seller will receive (price - seller-borne fee)
  int get sellerReceives => amount - sellerFee;

  /// Check if transaction is in a terminal state
  bool get isTerminal {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'REFUNDED' || s == 'CANCELLED';
  }

  /// Check if transaction is active (in-progress)
  bool get isActive => !isTerminal;

  /// Check if payment has expired while in PENDING
  bool get isExpired {
    final s = status.toUpperCase();
    return s == 'PENDING' &&
        expiresAt != null &&
        DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [id, txCode, status, amount, platformFee];
}
