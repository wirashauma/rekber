import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../errors/failures.dart';

/// Base UseCase contract for Clean Architecture
/// [Type] = return type, [Params] = input parameters
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// For use cases that don't require parameters
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
