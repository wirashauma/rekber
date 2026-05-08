import 'package:equatable/equatable.dart';

/// User domain entity
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role; // buyer, seller, admin
  final String kycStatus; // none, pending, verified, rejected
  final String? idCardUrl;
  final String? selfieUrl;
  final bool isActive;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.kycStatus,
    this.idCardUrl,
    this.selfieUrl,
    required this.isActive,
    required this.createdAt,
  });

  bool get isBuyer => role == 'buyer';
  bool get isSeller => role == 'seller';
  bool get isAdmin => role == 'admin';
  bool get isKycVerified => kycStatus == 'verified';
  bool get isKycPending => kycStatus == 'pending';

  @override
  List<Object?> get props => [id, email, fullName, role, kycStatus];
}
