import 'package:equatable/equatable.dart';
import '../../domain/entities/transaction_entity.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionListLoaded extends TransactionState {
  final List<TransactionEntity> transactions;

  const TransactionListLoaded({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

class TransactionDetailLoaded extends TransactionState {
  final TransactionEntity transaction;

  const TransactionDetailLoaded({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class TransactionActionLoading extends TransactionState {
  final String message;

  const TransactionActionLoading({this.message = 'Memproses...'});

  @override
  List<Object?> get props => [message];
}

class TransactionActionSuccess extends TransactionState {
  final String message;
  final TransactionEntity? transaction;

  const TransactionActionSuccess({required this.message, this.transaction});

  @override
  List<Object?> get props => [message, transaction];
}

class TransactionActionFailure extends TransactionState {
  final String message;
  final bool isConflict;

  const TransactionActionFailure({
    required this.message,
    this.isConflict = false,
  });

  @override
  List<Object?> get props => [message, isConflict];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError({required this.message});

  @override
  List<Object?> get props => [message];
}
