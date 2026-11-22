import 'package:equatable/equatable.dart';

class LedgerEntryEntity extends Equatable {
  final String id;
  final int amount;
  final String type; // CREDIT, DEBIT
  final int balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;

  const LedgerEntryEntity({
    required this.id,
    required this.amount,
    required this.type,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.createdAt,
  });

  bool get isCredit => type.toUpperCase() == 'CREDIT';
  bool get isDebit => type.toUpperCase() == 'DEBIT';

  @override
  List<Object?> get props => [id, amount, type, balanceAfter, createdAt];
}

class LedgerEntryModel extends LedgerEntryEntity {
  const LedgerEntryModel({
    required super.id,
    required super.amount,
    required super.type,
    required super.balanceAfter,
    super.referenceType,
    super.referenceId,
    super.description,
    required super.createdAt,
  });

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) {
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

    return LedgerEntryModel(
      id: json['id']?.toString() ?? '',
      amount: parseInt(json['amount']),
      type: (json['type'] ?? 'CREDIT').toString().toUpperCase(),
      balanceAfter: parseInt(json['balanceAfter'] ?? json['balance_after']),
      referenceType: json['referenceType']?.toString() ?? json['reference_type']?.toString(),
      referenceId: json['referenceId']?.toString() ?? json['reference_id']?.toString(),
      description: json['description']?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}
