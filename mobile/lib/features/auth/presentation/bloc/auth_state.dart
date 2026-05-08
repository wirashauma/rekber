import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

/// Auth BLoC States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  final String activeRole; // Current active view: buyer or seller

  const AuthAuthenticated({required this.user, required this.activeRole});

  @override
  List<Object?> get props => [user, activeRole];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthRegistrationSuccess extends AuthState {
  final String message;
  const AuthRegistrationSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
