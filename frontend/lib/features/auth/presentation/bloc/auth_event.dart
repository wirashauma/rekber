import 'package:equatable/equatable.dart';

/// Auth BLoC Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phone;
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRoleSwitched extends AuthEvent {
  final String newRole;
  const AuthRoleSwitched({required this.newRole});

  @override
  List<Object?> get props => [newRole];
}
