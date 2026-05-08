import 'package:equatable/equatable.dart';

/// Base Failure class for domain-level error handling
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// Server-side failures (Supabase, Edge Functions)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

/// Local cache/storage failures
class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

/// Validation failures
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure({required super.message, this.fieldErrors});

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

/// Permission/authorization failures
class PermissionFailure extends Failure {
  const PermissionFailure({super.message = 'Permission denied'});
}
