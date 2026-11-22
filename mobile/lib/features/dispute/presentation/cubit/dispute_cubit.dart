import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/dispute_entity.dart';
import '../../domain/repositories/dispute_repository.dart';
import 'dispute_state.dart';

class DisputeCubit extends Cubit<DisputeState> {
  final DisputeRepository repository;

  DisputeEntity? currentDispute;

  DisputeCubit({required this.repository}) : super(DisputeInitial());

  Future<void> loadDispute(String id) => loadDisputeById(id);

  Future<void> loadDisputeById(String id) async {
    emit(DisputeLoading());
    final result = await repository.getDisputeById(id);
    result.fold(
      (failure) => emit(DisputeError(message: failure.message)),
      (dispute) {
        currentDispute = dispute;
        emit(DisputeLoaded(dispute: dispute));
      },
    );
  }

  Future<DisputeEntity?> loadDisputeByTransactionId(String transactionId) async {
    emit(DisputeLoading());
    final result = await repository.getDisputeByTransactionId(transactionId);
    return result.fold(
      (failure) {
        emit(DisputeError(message: failure.message));
        return null;
      },
      (dispute) {
        currentDispute = dispute;
        emit(DisputeLoaded(dispute: dispute));
        return dispute;
      },
    );
  }

  Future<DisputeEntity?> openDispute({
    required String transactionId,
    required String reason,
    required String description,
    List<String>? fileIds,
    List<String>? filePaths,
  }) => submitDispute(
        transactionId: transactionId,
        reason: reason,
        description: description,
        fileIds: fileIds,
        filePaths: filePaths,
      );

  Future<DisputeEntity?> submitDispute({
    required String transactionId,
    required String reason,
    required String description,
    List<String>? fileIds,
    List<String>? filePaths,
  }) async {
    emit(const DisputeActionLoading(message: 'Mengajukan sengketa...'));

    final targetFileIds = <String>[];
    if (fileIds != null) {
      targetFileIds.addAll(fileIds);
    }

    if (filePaths != null && filePaths.isNotEmpty) {
      for (final path in filePaths) {
        final uploadRes = await repository.uploadDisputeEvidence(path);
        uploadRes.fold(
          (failure) {},
          (id) => targetFileIds.add(id),
        );
      }
    }

    final result = await repository.openDispute(
      transactionId: transactionId,
      reason: reason,
      description: description,
      fileIds: targetFileIds.isNotEmpty ? targetFileIds : null,
    );

    return result.fold(
      (failure) {
        emit(DisputeActionFailure(message: failure.message));
        return null;
      },
      (dispute) {
        currentDispute = dispute;
        emit(DisputeActionSuccess(
          message: 'Sengketa berhasil diajukan.',
          dispute: dispute,
        ));
        return dispute;
      },
    );
  }

  Future<bool> submitEvidence({
    required String disputeId,
    String? note,
    List<String>? fileIds,
    List<String>? filePaths,
  }) async {
    emit(const DisputeActionLoading(message: 'Mengunggah bukti...'));

    final targetFileIds = <String>[];
    if (fileIds != null) {
      targetFileIds.addAll(fileIds);
    }

    if (filePaths != null && filePaths.isNotEmpty) {
      for (final path in filePaths) {
        final uploadRes = await repository.uploadDisputeEvidence(path);
        uploadRes.fold(
          (failure) {},
          (id) => targetFileIds.add(id),
        );
      }
    }

    final result = await repository.submitEvidence(
      disputeId: disputeId,
      note: note,
      fileIds: targetFileIds.isNotEmpty ? targetFileIds : null,
    );

    return result.fold(
      (failure) {
        emit(DisputeActionFailure(message: failure.message));
        return false;
      },
      (_) {
        emit(const DisputeActionSuccess(message: 'Bukti sengketa berhasil ditambahkan.'));
        loadDisputeById(disputeId);
        return true;
      },
    );
  }
}
