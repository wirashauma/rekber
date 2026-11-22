import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../data/models/public_config_model.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository repository;

  PublicConfigModel? publicConfig;
  List<TransactionEntity> currentList = [];
  TransactionEntity? currentDetail;

  TransactionCubit({required this.repository}) : super(TransactionInitial());

  Future<void> loadTransactions() async {
    emit(TransactionLoading());
    final result = await repository.getTransactions();
    result.fold(
      (failure) => emit(TransactionError(message: failure.message)),
      (data) {
        currentList = data;
        emit(TransactionListLoaded(transactions: data));
      },
    );
  }

  Future<void> loadTransactionDetail(String id) async {
    emit(TransactionLoading());
    final result = await repository.getTransactionById(id);
    result.fold(
      (failure) => emit(TransactionError(message: failure.message)),
      (data) {
        currentDetail = data;
        emit(TransactionDetailLoaded(transaction: data));
      },
    );
  }

  Future<TransactionEntity?> loadTransactionByCode(String code) async {
    emit(TransactionLoading());
    final result = await repository.getTransactionByCode(code);
    return result.fold(
      (failure) {
        emit(TransactionError(message: failure.message));
        return null;
      },
      (data) {
        currentDetail = data;
        emit(TransactionDetailLoaded(transaction: data));
        return data;
      },
    );
  }

  Future<PublicConfigModel?> loadPublicConfig() async {
    final result = await repository.getPublicConfig();
    return result.fold(
      (_) => null,
      (config) {
        publicConfig = config;
        return config;
      },
    );
  }

  Future<bool> createTransaction({
    required int amount,
    required String itemDescription,
    required String feePayer,
    String? sellerId,
    String? buyerId,
  }) async {
    emit(const TransactionActionLoading(message: 'Membuat transaksi...'));
    final result = await repository.createTransaction(
      amount: amount,
      itemDescription: itemDescription,
      feePayer: feePayer,
      sellerId: sellerId,
      buyerId: buyerId,
    );
    return result.fold(
      (failure) {
        emit(TransactionActionFailure(message: failure.message));
        return false;
      },
      (tx) {
        currentDetail = tx;
        emit(TransactionActionSuccess(
          message: 'Transaksi berhasil dibuat.',
          transaction: tx,
        ));
        return true;
      },
    );
  }

  Future<void> payFromBalance(String id) async {
    emit(const TransactionActionLoading(message: 'Memproses pembayaran...'));
    final result = await repository.updateStatus(id: id, status: 'PAID');
    result.fold(
      (failure) {
        final isConflict = failure is ConflictFailure ||
            (failure is ServerFailure && failure.isConflict);
        emit(TransactionActionFailure(
          message: failure.message,
          isConflict: isConflict,
        ));
        if (isConflict) {
          loadTransactionDetail(id);
        }
      },
      (tx) {
        currentDetail = tx;
        emit(TransactionActionSuccess(
          message: 'Pembayaran berhasil dilakukan!',
          transaction: tx,
        ));
      },
    );
  }

  Future<void> confirmReceived(String id) async {
    emit(const TransactionActionLoading(message: 'Mengonfirmasi pesanan...'));
    final result = await repository.updateStatus(id: id, status: 'COMPLETED');
    result.fold(
      (failure) {
        final isConflict = failure is ConflictFailure ||
            (failure is ServerFailure && failure.isConflict);
        emit(TransactionActionFailure(
          message: failure.message,
          isConflict: isConflict,
        ));
        if (isConflict) {
          loadTransactionDetail(id);
        }
      },
      (tx) {
        currentDetail = tx;
        emit(TransactionActionSuccess(
          message: 'Transaksi selesai. Dana telah dilepas ke penjual.',
          transaction: tx,
        ));
      },
    );
  }

  Future<void> cancelTransaction(String id) async {
    emit(const TransactionActionLoading(message: 'Membatalkan transaksi...'));
    final result = await repository.updateStatus(id: id, status: 'CANCELLED');
    result.fold(
      (failure) {
        final isConflict = failure is ConflictFailure ||
            (failure is ServerFailure && failure.isConflict);
        emit(TransactionActionFailure(
          message: failure.message,
          isConflict: isConflict,
        ));
        if (isConflict) {
          loadTransactionDetail(id);
        }
      },
      (tx) {
        currentDetail = tx;
        emit(TransactionActionSuccess(
          message: 'Transaksi berhasil dibatalkan.',
          transaction: tx,
        ));
      },
    );
  }

  Future<void> submitShipment({
    required String id,
    required String courier,
    required String trackingNumber,
    String? note,
    required String proofFilePath,
  }) async {
    emit(const TransactionActionLoading(message: 'Mengunggah bukti pengiriman...'));
    
    // Step 1: Upload proof file
    final uploadResult = await repository.uploadShipmentProof(proofFilePath);
    final fileId = uploadResult.fold<String?>(
      (failure) {
        emit(TransactionActionFailure(message: failure.message));
        return null;
      },
      (fId) => fId,
    );

    if (fileId == null) return;

    // Step 2: Submit shipment details
    emit(const TransactionActionLoading(message: 'Menyimpan bukti pengiriman...'));
    final result = await repository.submitShipment(
      id: id,
      courier: courier,
      trackingNumber: trackingNumber,
      note: note,
      fileIds: [fileId],
    );

    result.fold(
      (failure) {
        final isConflict = failure is ConflictFailure ||
            (failure is ServerFailure && failure.isConflict);
        emit(TransactionActionFailure(
          message: failure.message,
          isConflict: isConflict,
        ));
        if (isConflict) {
          loadTransactionDetail(id);
        }
      },
      (tx) {
        currentDetail = tx;
        emit(TransactionActionSuccess(
          message: 'Pesanan ditandai telah dikirim!',
          transaction: tx,
        ));
      },
    );
  }
}
