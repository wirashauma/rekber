import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

/// Represents a valid state transition in the escrow lifecycle
class EscrowTransition {
  final String fromStatus;
  final String toStatus;
  final String requiredRole; // buyer, seller, admin, system
  final String description;

  const EscrowTransition({
    required this.fromStatus,
    required this.toStatus,
    required this.requiredRole,
    required this.description,
  });
}

/// Escrow State Machine — enforces canonical backend status lifecycle
class EscrowStateMachine {
  EscrowStateMachine._();

  /// Canonical status order for progress display
  static const List<String> statusOrder = [
    'PENDING',
    'PAID',
    'SHIPPED',
    'COMPLETED',
  ];

  /// Terminal states — no further transitions possible
  static const Set<String> terminalStates = {
    'COMPLETED',
    'REFUNDED',
    'CANCELLED',
  };

  /// All valid transitions in the escrow lifecycle
  static const List<EscrowTransition> _transitions = [
    // PENDING -> PAID (buyer pays from balance / gateway webhook)
    EscrowTransition(
      fromStatus: 'PENDING',
      toStatus: 'PAID',
      requiredRole: 'buyer',
      description: 'Pembeli melakukan pembayaran, dana ditahan di rekber',
    ),
    EscrowTransition(
      fromStatus: 'PENDING',
      toStatus: 'PAID',
      requiredRole: 'system',
      description: 'Pembayaran diverifikasi oleh sistem, dana masuk ke escrow',
    ),

    // PENDING -> CANCELLED (buyer or seller cancels before payment)
    EscrowTransition(
      fromStatus: 'PENDING',
      toStatus: 'CANCELLED',
      requiredRole: 'buyer',
      description: 'Pembeli membatalkan transaksi sebelum pembayaran',
    ),
    EscrowTransition(
      fromStatus: 'PENDING',
      toStatus: 'CANCELLED',
      requiredRole: 'seller',
      description: 'Penjual membatalkan transaksi sebelum pembayaran',
    ),

    // PAID -> SHIPPED (seller ships the product and uploads proof)
    EscrowTransition(
      fromStatus: 'PAID',
      toStatus: 'SHIPPED',
      requiredRole: 'seller',
      description: 'Penjual mengirimkan barang pesanan dengan bukti pengiriman',
    ),

    // SHIPPED -> COMPLETED (buyer confirms receipt, funds released to seller)
    EscrowTransition(
      fromStatus: 'SHIPPED',
      toStatus: 'COMPLETED',
      requiredRole: 'buyer',
      description: 'Pembeli mengonfirmasi penerimaan barang, dana diteruskan ke penjual',
    ),
    EscrowTransition(
      fromStatus: 'SHIPPED',
      toStatus: 'COMPLETED',
      requiredRole: 'system',
      description: 'Auto-release setelah batas waktu tercapai, dana dilepas ke penjual',
    ),

    // PAID or SHIPPED -> DISPUTED (buyer raises dispute)
    EscrowTransition(
      fromStatus: 'PAID',
      toStatus: 'DISPUTED',
      requiredRole: 'buyer',
      description: 'Pembeli mengajukan sengketa',
    ),
    EscrowTransition(
      fromStatus: 'SHIPPED',
      toStatus: 'DISPUTED',
      requiredRole: 'buyer',
      description: 'Pembeli mengajukan sengketa pengiriman/barang',
    ),

    // DISPUTED -> COMPLETED / REFUNDED (admin resolves dispute)
    EscrowTransition(
      fromStatus: 'DISPUTED',
      toStatus: 'COMPLETED',
      requiredRole: 'admin',
      description: 'Admin memenangkan penjual, dana diteruskan ke penjual',
    ),
    EscrowTransition(
      fromStatus: 'DISPUTED',
      toStatus: 'REFUNDED',
      requiredRole: 'admin',
      description: 'Admin memenangkan pembeli, dana dikembalikan ke pembeli',
    ),
  ];

  /// Validate if a transition is allowed
  static Either<Failure, EscrowTransition> validateTransition({
    required String currentStatus,
    required String targetStatus,
    required String userRole,
  }) {
    final cur = currentStatus.toUpperCase();
    final tgt = targetStatus.toUpperCase();

    if (terminalStates.contains(cur)) {
      return Left(ValidationFailure(
        message: 'Transaksi sudah selesai dengan status: ${getStatusLabel(cur)}',
      ));
    }

    final matches = _transitions.where(
      (t) => t.fromStatus == cur && t.toStatus == tgt,
    );

    if (matches.isEmpty) {
      return Left(ValidationFailure(
        message: 'Tidak dapat mengubah status dari ${getStatusLabel(cur)} ke ${getStatusLabel(tgt)}',
      ));
    }

    final role = userRole.toLowerCase();
    final validTransition = matches.firstWhere(
      (t) => t.requiredRole == role || t.requiredRole == 'system',
      orElse: () => matches.first,
    );

    if (validTransition.requiredRole != role &&
        validTransition.requiredRole != 'system') {
      return Left(PermissionFailure(
        message: 'Hanya ${_getRoleLabel(validTransition.requiredRole)} yang dapat melakukan aksi ini',
      ));
    }

    return Right(validTransition);
  }

  /// Get current step index (0-based) for stepper
  static int getStepIndex(String status) {
    final index = statusOrder.indexOf(status.toUpperCase());
    return index >= 0 ? index : 0;
  }

  /// Get progress percentage (0.0 to 1.0)
  static double getProgressPercent(String status) {
    final s = status.toUpperCase();
    final index = statusOrder.indexOf(s);
    if (index == -1) {
      if (s == 'DISPUTED') return 0.75;
      if (s == 'REFUNDED') return 1.0;
      if (s == 'CANCELLED') return 0.0;
      return 0.0;
    }
    return index / (statusOrder.length - 1);
  }

  /// Indonesian human-readable label
  static String getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Pembayaran';
      case 'PAID':
        return 'Dana Ditahan di Rekber';
      case 'SHIPPED':
        return 'Barang Dikirim';
      case 'COMPLETED':
        return 'Selesai';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'DISPUTED':
        return 'Dalam Sengketa';
      case 'REFUNDED':
        return 'Dana Dikembalikan';
      default:
        return status;
    }
  }

  /// Detailed Indonesian description
  static String getStatusDescription(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Silakan lakukan pembayaran sebelum batas waktu berakhir.';
      case 'PAID':
        return 'Pembayaran berhasil. Dana aman ditahan oleh REKBER hingga barang diterima.';
      case 'SHIPPED':
        return 'Penjual telah mengirimkan pesanan. Mohon periksa barang sebelum konfirmasi.';
      case 'COMPLETED':
        return 'Transaksi selesai. Dana telah diteruskan ke penjual.';
      case 'CANCELLED':
        return 'Transaksi telah dibatalkan.';
      case 'DISPUTED':
        return 'Sengketa sedang ditinjau oleh Admin REKBER.';
      case 'REFUNDED':
        return 'Sengketa diselesaikan. Dana telah dikembalikan ke saldo pembeli.';
      default:
        return '';
    }
  }

  static String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'buyer':
        return 'Pembeli';
      case 'seller':
        return 'Penjual';
      case 'admin':
        return 'Admin';
      case 'system':
        return 'Sistem';
      default:
        return role;
    }
  }
}
