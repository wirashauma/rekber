/// ============================================================
/// REKBER - Escrow State Machine Service
/// ============================================================
/// Handles all transaction state transitions with validation,
/// ensuring the escrow lifecycle is enforced correctly.
/// ============================================================

import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';

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

/// Escrow State Machine — enforces the transaction lifecycle
class EscrowStateMachine {
  EscrowStateMachine._();

  /// All valid transitions in the escrow lifecycle
  static const List<EscrowTransition> _transitions = [
    // Buyer creates → awaiting payment
    EscrowTransition(
      fromStatus: 'awaiting_payment',
      toStatus: 'escrow',
      requiredRole: 'system',
      description: 'Payment confirmed, funds held in escrow',
    ),
    EscrowTransition(
      fromStatus: 'awaiting_payment',
      toStatus: 'cancelled',
      requiredRole: 'buyer',
      description: 'Buyer cancelled before payment',
    ),

    // Escrow → Seller processes
    EscrowTransition(
      fromStatus: 'escrow',
      toStatus: 'processed',
      requiredRole: 'seller',
      description: 'Seller accepted and is processing order',
    ),

    // Processed → Seller ships
    EscrowTransition(
      fromStatus: 'processed',
      toStatus: 'shipped',
      requiredRole: 'seller',
      description: 'Seller shipped the order with proof',
    ),

    // Shipped → Buyer confirms or disputes
    EscrowTransition(
      fromStatus: 'shipped',
      toStatus: 'completed',
      requiredRole: 'buyer',
      description: 'Buyer confirmed receipt, funds released',
    ),
    EscrowTransition(
      fromStatus: 'shipped',
      toStatus: 'disputed',
      requiredRole: 'buyer',
      description: 'Buyer raised a dispute',
    ),

    // Disputed → Admin resolves
    EscrowTransition(
      fromStatus: 'disputed',
      toStatus: 'completed',
      requiredRole: 'admin',
      description: 'Admin resolved dispute in seller favor',
    ),
    EscrowTransition(
      fromStatus: 'disputed',
      toStatus: 'refunded',
      requiredRole: 'admin',
      description: 'Admin resolved dispute in buyer favor',
    ),
  ];

  /// Terminal states — no further transitions possible
  static const Set<String> terminalStates = {
    'completed',
    'refunded',
    'cancelled',
  };

  /// All possible statuses in order
  static const List<String> statusOrder = [
    'awaiting_payment',
    'escrow',
    'processed',
    'shipped',
    'completed',
  ];

  /// Validate if a transition is allowed
  static Either<Failure, EscrowTransition> validateTransition({
    required String currentStatus,
    required String targetStatus,
    required String userRole,
  }) {
    // Check if current status is terminal
    if (terminalStates.contains(currentStatus)) {
      return Left(ValidationFailure(
        message: 'Transaksi sudah selesai dengan status: $currentStatus',
      ));
    }

    // Find matching transition
    final transition = _transitions.where(
      (t) => t.fromStatus == currentStatus && t.toStatus == targetStatus,
    );

    if (transition.isEmpty) {
      return Left(ValidationFailure(
        message: 'Tidak dapat mengubah status dari $currentStatus ke $targetStatus',
      ));
    }

    final validTransition = transition.first;

    // Check role authorization
    if (validTransition.requiredRole != userRole &&
        validTransition.requiredRole != 'system') {
      return Left(PermissionFailure(
        message: 'Hanya ${_getRoleLabel(validTransition.requiredRole)} yang dapat melakukan aksi ini',
      ));
    }

    return Right(validTransition);
  }

  /// Get available next statuses for a given current status and role
  static List<String> getAvailableTransitions({
    required String currentStatus,
    required String userRole,
  }) {
    return _transitions
        .where((t) =>
            t.fromStatus == currentStatus &&
            (t.requiredRole == userRole || t.requiredRole == 'system'))
        .map((t) => t.toStatus)
        .toList();
  }

  /// Get the progress percentage (0.0 to 1.0) for the status tracker
  static double getProgressPercent(String status) {
    final index = statusOrder.indexOf(status);
    if (index == -1) {
      // Handle non-standard statuses
      if (status == 'disputed') return 0.8;
      if (status == 'refunded') return 1.0;
      if (status == 'cancelled') return 0.0;
      return 0.0;
    }
    return index / (statusOrder.length - 1);
  }

  /// Get the current step index (for stepper widgets)
  static int getStepIndex(String status) {
    final index = statusOrder.indexOf(status);
    return index >= 0 ? index : 0;
  }

  /// Get human-readable status label in Indonesian
  static String getStatusLabel(String status) {
    const labels = {
      'awaiting_payment': 'Menunggu Pembayaran',
      'escrow': 'Dana Ditahan',
      'processed': 'Diproses Penjual',
      'shipped': 'Dikirim',
      'completed': 'Selesai',
      'disputed': 'Sengketa',
      'refunded': 'Dana Dikembalikan',
      'cancelled': 'Dibatalkan',
    };
    return labels[status] ?? status;
  }

  /// Get status description for the detail screen
  static String getStatusDescription(String status) {
    const descriptions = {
      'awaiting_payment': 'Silakan lakukan pembayaran sebelum batas waktu berakhir.',
      'escrow': 'Pembayaran berhasil. Dana aman ditahan oleh REKBER hingga transaksi selesai.',
      'processed': 'Penjual sedang memproses pesanan Anda.',
      'shipped': 'Pesanan telah dikirim. Silakan konfirmasi setelah menerima barang.',
      'completed': 'Transaksi selesai. Dana telah dilepas ke penjual.',
      'disputed': 'Sengketa sedang ditinjau oleh admin. Harap tunggu keputusan.',
      'refunded': 'Sengketa diselesaikan. Dana telah dikembalikan ke pembeli.',
      'cancelled': 'Transaksi dibatalkan.',
    };
    return descriptions[status] ?? '';
  }

  static String _getRoleLabel(String role) {
    const labels = {
      'buyer': 'Pembeli',
      'seller': 'Penjual',
      'admin': 'Admin',
      'system': 'Sistem',
    };
    return labels[role] ?? role;
  }
}
