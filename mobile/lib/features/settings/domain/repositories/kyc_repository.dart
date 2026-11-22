import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class KycRepository {
  Future<Either<Failure, Map<String, dynamic>>> getMyKyc();
  Future<Either<Failure, String>> uploadKycFile(File file, String purpose);
  Future<Either<Failure, Map<String, dynamic>>> submitKyc({
    required String fullName,
    required String nik,
    required String idFileId,
    required String selfieFileId,
  });
}
