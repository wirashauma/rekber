import 'package:equatable/equatable.dart';
import 'bank_account_entity.dart';

class WithdrawalEntity extends Equatable {
  final String id;
  final String bankAccountId;
  final int amount;
  final int fee;
  final String status; // PENDING_REVIEW, APPROVED, PROCESSING, COMPLETED, REJECTED, FAILED, CANCELLED
  final String? failureReason;
  final BankAccountEntity? bankAccount;
  final DateTime createdAt;

  const WithdrawalEntity({
    required this.id,
    required this.bankAccountId,
    required this.amount,
    required this.fee,
    required this.status,
    this.failureReason,
    this.bankAccount,
    required this.createdAt,
  });

  int get netAmount => amount - fee;
  bool get canCancel => status.toUpperCase() == 'PENDING_REVIEW';

  @override
  List<Object?> get props => [id, bankAccountId, amount, fee, status];
}

class WithdrawalModel extends WithdrawalEntity {
  const WithdrawalModel({
    required super.id,
    required super.bankAccountId,
    required super.amount,
    required super.fee,
    required super.status,
    super.failureReason,
    super.bankAccount,
    required super.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    BankAccountEntity? parsedBank;
    if (json['bankAccount'] != null && json['bankAccount'] is Map<String, dynamic>) {
      parsedBank = BankAccountModel.fromJson(json['bankAccount']);
    } else if (json['bank_account'] != null && json['bank_account'] is Map<String, dynamic>) {
      parsedBank = BankAccountModel.fromJson(json['bank_account']);
    }

    return WithdrawalModel(
      id: json['id']?.toString() ?? '',
      bankAccountId: json['bankAccountId']?.toString() ?? json['bank_account_id']?.toString() ?? '',
      amount: parseInt(json['amount']),
      fee: parseInt(json['fee']),
      status: (json['status'] ?? 'PENDING_REVIEW').toString().toUpperCase(),
      failureReason: json['failureReason']?.toString() ?? json['failure_reason']?.toString(),
      bankAccount: parsedBank,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}
