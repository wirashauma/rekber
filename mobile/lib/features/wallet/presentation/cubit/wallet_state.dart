import 'package:equatable/equatable.dart';
import '../../domain/entities/wallet_summary_entity.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../../domain/entities/payment_intent_entity.dart';
import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/withdrawal_entity.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final WalletSummaryEntity summary;
  final List<BankAccountEntity> bankAccounts;
  final List<WithdrawalEntity> withdrawals;
  final List<LedgerEntryEntity> ledgerEntries;

  const WalletLoaded({
    required this.summary,
    this.bankAccounts = const [],
    this.withdrawals = const [],
    this.ledgerEntries = const [],
  });

  WalletLoaded copyWith({
    WalletSummaryEntity? summary,
    List<BankAccountEntity>? bankAccounts,
    List<WithdrawalEntity>? withdrawals,
    List<LedgerEntryEntity>? ledgerEntries,
  }) {
    return WalletLoaded(
      summary: summary ?? this.summary,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      withdrawals: withdrawals ?? this.withdrawals,
      ledgerEntries: ledgerEntries ?? this.ledgerEntries,
    );
  }

  @override
  List<Object?> get props => [summary, bankAccounts, withdrawals, ledgerEntries];
}

class WalletActionLoading extends WalletState {
  final String message;

  const WalletActionLoading({this.message = 'Memproses...'});

  @override
  List<Object?> get props => [message];
}

class WalletActionSuccess extends WalletState {
  final String message;

  const WalletActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class TopUpCreatedSuccess extends WalletState {
  final PaymentIntentEntity paymentIntent;

  const TopUpCreatedSuccess({required this.paymentIntent});

  @override
  List<Object?> get props => [paymentIntent];
}

class WalletActionFailure extends WalletState {
  final String message;
  final bool isKycRequired;

  const WalletActionFailure({
    required this.message,
    this.isKycRequired = false,
  });

  @override
  List<Object?> get props => [message, isKycRequired];
}

class WalletError extends WalletState {
  final String message;

  const WalletError({required this.message});

  @override
  List<Object?> get props => [message];
}
