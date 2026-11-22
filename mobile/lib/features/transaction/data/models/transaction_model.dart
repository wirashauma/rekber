import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.txCode,
    required super.buyerId,
    required super.sellerId,
    required super.amount,
    required super.platformFee,
    super.buyerFee = 0,
    super.sellerFee = 0,
    super.feePayer = 'SPLIT',
    required super.status,
    super.description,
    super.paidAt,
    super.shippedAt,
    super.completedAt,
    super.cancelledAt,
    super.refundedAt,
    super.disputedAt,
    super.autoReleaseAt,
    super.expiresAt,
    required super.createdAt,
    super.courier,
    super.trackingNumber,
    super.shipmentNote,
    super.shipmentProofUrls = const [],
    super.buyerName,
    super.sellerName,
    super.buyerEmail,
    super.sellerEmail,
    super.buyerAvatar,
    super.sellerAvatar,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    List<String> parseProofs(dynamic proofs) {
      if (proofs == null || proofs is! List) return [];
      final urls = <String>[];
      for (final item in proofs) {
        if (item is String) {
          urls.add(item);
        } else if (item is Map) {
          final url = item['url'] ?? item['storageKey'] ?? item['id'];
          if (url != null) urls.add(url.toString());
        }
      }
      return urls;
    }

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      txCode: json['txCode']?.toString() ??
          json['tx_code']?.toString() ??
          (json['id']?.toString().length != null && json['id']!.toString().length > 8
              ? json['id']!.toString().substring(0, 8).toUpperCase()
              : json['id']?.toString().toUpperCase() ?? 'TRX-UNKNOWN'),
      buyerId: json['buyerId']?.toString() ?? json['buyer_id']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? json['seller_id']?.toString() ?? '',
      amount: parseInt(json['amount']),
      platformFee: parseInt(json['platformFee'] ?? json['platform_fee']),
      buyerFee: parseInt(json['buyerFee'] ?? json['buyer_fee']),
      sellerFee: parseInt(json['sellerFee'] ?? json['seller_fee']),
      feePayer: (json['feePayer'] ?? json['fee_payer'] ?? 'SPLIT').toString().toUpperCase(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      description: json['itemDescription']?.toString() ??
          json['description']?.toString() ??
          json['item_description']?.toString(),
      paidAt: parseDate(json['paidAt'] ?? json['paid_at']),
      shippedAt: parseDate(json['shippedAt'] ?? json['shipped_at']),
      completedAt: parseDate(json['completedAt'] ?? json['completed_at']),
      cancelledAt: parseDate(json['cancelledAt'] ?? json['cancelled_at']),
      refundedAt: parseDate(json['refundedAt'] ?? json['refunded_at']),
      disputedAt: parseDate(json['disputedAt'] ?? json['disputed_at']),
      autoReleaseAt: parseDate(json['autoReleaseAt'] ?? json['auto_release_at']),
      expiresAt: parseDate(json['expiresAt'] ?? json['expires_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      courier: json['courier']?.toString(),
      trackingNumber: json['trackingNumber']?.toString() ?? json['tracking_number']?.toString(),
      shipmentNote: json['shipmentNote']?.toString() ?? json['shipment_note']?.toString(),
      shipmentProofUrls: parseProofs(json['shipmentProofs'] ?? json['shipment_proofs']),
      buyerName: json['buyer']?['fullName'] ?? json['buyer']?['name'],
      sellerName: json['seller']?['fullName'] ?? json['seller']?['name'],
      buyerEmail: json['buyer']?['email'],
      sellerEmail: json['seller']?['email'],
      buyerAvatar: json['buyer']?['avatar_url'] ?? json['buyer']?['avatarUrl'],
      sellerAvatar: json['seller']?['avatar_url'] ?? json['seller']?['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txCode': txCode,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'amount': amount,
      'platformFee': platformFee,
      'buyerFee': buyerFee,
      'sellerFee': sellerFee,
      'feePayer': feePayer,
      'status': status,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
