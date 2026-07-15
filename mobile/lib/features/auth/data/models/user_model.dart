import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    super.avatarUrl,
    required super.role,
    required super.kycStatus,
    super.idCardUrl,
    super.selfieUrl,
    required super.isActive,
    required super.createdAt,
    double? balance,
  }) : _balance = balance ?? 0.0;

  final double _balance;

  double get balance => _balance;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['name'] ?? json['full_name'] ?? 'Guest',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'buyer',
      kycStatus: json['kyc_status'] ?? 'none',
      idCardUrl: json['id_card_url'],
      selfieUrl: json['selfie_url'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      balance: (json['balance'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'kyc_status': kycStatus,
      'id_card_url': idCardUrl,
      'selfie_url': selfieUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'balance': balance,
    };
  }
}
