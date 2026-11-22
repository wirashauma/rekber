import 'package:equatable/equatable.dart';

class BankAccountEntity extends Equatable {
  final String id;
  final String bankCode;
  final String accountLast4;
  final String accountName;
  final bool isDefault;
  final DateTime createdAt;

  const BankAccountEntity({
    required this.id,
    required this.bankCode,
    required this.accountLast4,
    required this.accountName,
    this.isDefault = false,
    required this.createdAt,
  });

  String get maskedNumber => '•••• $accountLast4';

  @override
  List<Object?> get props => [id, bankCode, accountLast4, accountName, isDefault];
}

class BankAccountModel extends BankAccountEntity {
  const BankAccountModel({
    required super.id,
    required super.bankCode,
    required super.accountLast4,
    required super.accountName,
    super.isDefault = false,
    required super.createdAt,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return BankAccountModel(
      id: json['id']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? json['bank_code']?.toString() ?? '',
      accountLast4: json['accountLast4']?.toString() ?? json['account_last4']?.toString() ?? '••••',
      accountName: json['accountName']?.toString() ?? json['account_name']?.toString() ?? '',
      isDefault: json['isDefault'] == true || json['is_default'] == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}
