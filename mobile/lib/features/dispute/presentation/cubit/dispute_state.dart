import 'package:equatable/equatable.dart';
import '../../domain/entities/dispute_entity.dart';

abstract class DisputeState extends Equatable {
  const DisputeState();

  @override
  List<Object?> get props => [];
}

class DisputeInitial extends DisputeState {}

class DisputeLoading extends DisputeState {}

class DisputeLoaded extends DisputeState {
  final DisputeEntity dispute;

  const DisputeLoaded({required this.dispute});

  @override
  List<Object?> get props => [dispute];
}

class DisputeActionLoading extends DisputeState {
  final String message;

  const DisputeActionLoading({this.message = 'Memproses...'});

  @override
  List<Object?> get props => [message];
}

class DisputeActionSuccess extends DisputeState {
  final String message;
  final DisputeEntity? dispute;

  const DisputeActionSuccess({required this.message, this.dispute});

  @override
  List<Object?> get props => [message, dispute];
}

class DisputeActionFailure extends DisputeState {
  final String message;

  const DisputeActionFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class DisputeError extends DisputeState {
  final String message;

  const DisputeError({required this.message});

  @override
  List<Object?> get props => [message];
}
