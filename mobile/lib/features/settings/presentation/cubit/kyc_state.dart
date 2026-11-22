import 'package:equatable/equatable.dart';

abstract class KycState extends Equatable {
  const KycState();

  @override
  List<Object?> get props => [];
}

class KycInitial extends KycState {
  const KycInitial();
}

class KycLoading extends KycState {
  const KycLoading();
}

class KycLoaded extends KycState {
  final String status; // 'NONE', 'PENDING', 'APPROVED', 'REJECTED'
  final String? rejectionReason;
  final String? nikMasked;
  final String? fullName;
  final DateTime? createdAt;

  const KycLoaded({
    required this.status,
    this.rejectionReason,
    this.nikMasked,
    this.fullName,
    this.createdAt,
  });

  bool get isNone => status == 'NONE';
  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get canSubmit => isNone || isRejected;

  @override
  List<Object?> get props => [status, rejectionReason, nikMasked, fullName, createdAt];
}

class KycSubmitting extends KycState {
  final String step;
  const KycSubmitting({required this.step});

  @override
  List<Object?> get props => [step];
}

class KycSubmitSuccess extends KycState {
  final String message;
  const KycSubmitSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class KycFailure extends KycState {
  final String message;
  const KycFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
