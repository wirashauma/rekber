import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/kyc_repository.dart';
import 'kyc_state.dart';

class KycCubit extends Cubit<KycState> {
  final KycRepository _kycRepository;

  KycCubit({required KycRepository kycRepository})
      : _kycRepository = kycRepository,
        super(const KycInitial());

  Future<void> fetchKycStatus() async {
    emit(const KycLoading());
    final result = await _kycRepository.getMyKyc();
    result.fold(
      (failure) => emit(KycFailure(message: failure.message)),
      (data) {
        final status = (data['kycStatus'] ?? 'NONE').toString();
        final submission = data['submission'] as Map<String, dynamic>?;
        emit(KycLoaded(
          status: status,
          rejectionReason: submission?['rejectionReason'] as String?,
          nikMasked: submission?['nikMasked'] as String?,
          fullName: submission?['fullName'] as String?,
          createdAt: submission?['createdAt'] != null
              ? DateTime.tryParse(submission!['createdAt'].toString())
              : null,
        ));
      },
    );
  }

  Future<void> submitKyc({
    required String fullName,
    required String nik,
    required File idCardFile,
    required File selfieFile,
  }) async {
    final cleanNik = nik.trim();
    if (!RegExp(r'^\d{16}$').hasMatch(cleanNik)) {
      emit(const KycFailure(message: 'NIK harus terdiri dari tepat 16 digit angka.'));
      return;
    }

    if (fullName.trim().length < 3) {
      emit(const KycFailure(message: 'Nama lengkap minimal 3 karakter.'));
      return;
    }

    emit(const KycSubmitting(step: 'Mengunggah foto KTP...'));
    final idUploadResult = await _kycRepository.uploadKycFile(idCardFile, 'KYC_ID');
    String? idFileId;
    String? uploadError;

    idUploadResult.fold(
      (failure) => uploadError = failure.message,
      (fileId) => idFileId = fileId,
    );

    if (uploadError != null || idFileId == null) {
      emit(KycFailure(message: uploadError ?? 'Gagal mengunggah foto KTP.'));
      return;
    }

    emit(const KycSubmitting(step: 'Mengunggah foto selfie...'));
    final selfieUploadResult = await _kycRepository.uploadKycFile(selfieFile, 'KYC_SELFIE');
    String? selfieFileId;

    selfieUploadResult.fold(
      (failure) => uploadError = failure.message,
      (fileId) => selfieFileId = fileId,
    );

    if (uploadError != null || selfieFileId == null) {
      emit(KycFailure(message: uploadError ?? 'Gagal mengunggah foto selfie.'));
      return;
    }

    emit(const KycSubmitting(step: 'Mengirim permohonan verifikasi...'));
    final submitResult = await _kycRepository.submitKyc(
      fullName: fullName.trim(),
      nik: cleanNik,
      idFileId: idFileId!,
      selfieFileId: selfieFileId!,
    );

    submitResult.fold(
      (failure) => emit(KycFailure(message: failure.message)),
      (_) {
        emit(const KycSubmitSuccess(
          message: 'Permohonan verifikasi identitas (KYC) berhasil dikirim.',
        ));
        fetchKycStatus();
      },
    );
  }
}
