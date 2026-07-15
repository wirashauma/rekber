import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.txCode,
    required super.buyerId,
    required super.sellerId,
    super.productId,
    required super.amount,
    required super.platformFee,
    required super.status,
    super.description,
    super.paymentMethod,
    super.paymentReference,
    super.metadata,
    super.paidAt,
    super.shippedAt,
    super.completedAt,
    super.disputedAt,
    super.expiresAt,
    required super.createdAt,
    super.buyerName,
    super.sellerName,
    super.buyerAvatar,
    super.sellerAvatar,
    super.productName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      txCode: json['tx_code'] ?? (json['id']?.toString().length != null && json['id']!.toString().length > 8 
          ? json['id']!.toString().substring(0, 8).toUpperCase() 
          : json['id']?.toString().toUpperCase() ?? 'TRX-UNKNOWN'),
      buyerId: json['buyer_id'] ?? '',
      sellerId: json['seller_id'] ?? '',
      productId: json['product_id'],
      amount: (json['amount'] ?? 0).toInt(),
      platformFee: (json['platform_fee'] ?? 0).toInt(),
      status: json['status'] ?? 'pending',
      description: json['item_description'] ?? json['description'],
      paymentMethod: json['payment_method'],
      paymentReference: json['payment_reference'],
      metadata: json['metadata'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      shippedAt: json['shipped_at'] != null ? DateTime.parse(json['shipped_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      disputedAt: json['disputed_at'] != null ? DateTime.parse(json['disputed_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      buyerName: json['buyer']?['name'],
      sellerName: json['seller']?['name'],
      buyerAvatar: json['buyer']?['avatar_url'],
      sellerAvatar: json['seller']?['avatar_url'],
      productName: json['product']?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tx_code': txCode,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'amount': amount,
      'platform_fee': platformFee,
      'status': status,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
