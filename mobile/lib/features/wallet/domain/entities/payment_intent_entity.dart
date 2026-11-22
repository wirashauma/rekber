import 'package:equatable/equatable.dart';

class PaymentIntentEntity extends Equatable {
  final String id;
  final String provider;
  final String referenceId;
  final String? providerRef;
  final int amount;
  final String method; // QRIS, VIRTUAL_ACCOUNT
  final String status; // PENDING, PAID, EXPIRED, FAILED
  final String? qrString;
  final String? vaNumber;
  final String? bankCode;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime createdAt;

  const PaymentIntentEntity({
    required this.id,
    required this.provider,
    required this.referenceId,
    this.providerRef,
    required this.amount,
    required this.method,
    required this.status,
    this.qrString,
    this.vaNumber,
    this.bankCode,
    this.expiresAt,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  @override
  List<Object?> get props => [id, referenceId, amount, method, status];
}

class PaymentIntentModel extends PaymentIntentEntity {
  const PaymentIntentModel({
    required super.id,
    required super.provider,
    required super.referenceId,
    super.providerRef,
    required super.amount,
    required super.method,
    required super.status,
    super.qrString,
    super.vaNumber,
    super.bankCode,
    super.expiresAt,
    super.paidAt,
    required super.createdAt,
  });

  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
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

    return PaymentIntentModel(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'XENDIT',
      referenceId: json['referenceId']?.toString() ?? json['reference_id']?.toString() ?? '',
      providerRef: json['providerRef']?.toString() ?? json['provider_ref']?.toString(),
      amount: parseInt(json['amount']),
      method: (json['method'] ?? 'QRIS').toString().toUpperCase(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      qrString: json['qrString']?.toString() ?? json['qr_string']?.toString(),
      vaNumber: json['vaNumber']?.toString() ?? json['va_number']?.toString(),
      bankCode: json['bankCode']?.toString() ?? json['bank_code']?.toString(),
      expiresAt: parseDate(json['expiresAt'] ?? json['expires_at']),
      paidAt: parseDate(json['paidAt'] ?? json['paid_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }
}
