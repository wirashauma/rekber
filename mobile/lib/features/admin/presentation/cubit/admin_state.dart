import 'package:equatable/equatable.dart';

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  final String? message;
  const AdminLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class AdminDashboardLoaded extends AdminState {
  final Map<String, dynamic> metrics;
  const AdminDashboardLoaded({required this.metrics});

  int get gmv => (metrics['gmv'] as num?)?.toInt() ?? 0;
  int get heldAmount => (metrics['heldAmount'] as num?)?.toInt() ?? 0;
  int get feeRevenue => (metrics['platformFeeRevenue'] as num?)?.toInt() ?? 0;
  int get newUsers => (metrics['newUsers'] as num?)?.toInt() ?? 0;
  int get openDisputes => (metrics['openDisputes'] as num?)?.toInt() ?? 0;
  int get pendingWithdrawals => (metrics['pendingWithdrawals'] as num?)?.toInt() ?? 0;
  Map<String, int> get transactionsByStatus {
    final raw = metrics['transactionsByStatus'] as Map<String, dynamic>?;
    if (raw == null) return {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  @override
  List<Object?> get props => [metrics];
}

class AdminDisputesLoaded extends AdminState {
  final List<Map<String, dynamic>> disputes;
  final String statusFilter;
  final Map<String, dynamic>? pagination;

  const AdminDisputesLoaded({
    required this.disputes,
    required this.statusFilter,
    this.pagination,
  });

  @override
  List<Object?> get props => [disputes, statusFilter, pagination];
}

class AdminKycLoaded extends AdminState {
  final List<Map<String, dynamic>> submissions;
  final String statusFilter;
  final String? nextCursor;
  final bool hasMore;

  const AdminKycLoaded({
    required this.submissions,
    required this.statusFilter,
    this.nextCursor,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [submissions, statusFilter, nextCursor, hasMore];
}

class AdminUsersLoaded extends AdminState {
  final List<Map<String, dynamic>> users;
  final String searchQuery;
  final String? nextCursor;
  final bool hasMore;

  const AdminUsersLoaded({
    required this.users,
    this.searchQuery = '',
    this.nextCursor,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [users, searchQuery, nextCursor, hasMore];
}

class AdminSettingsLoaded extends AdminState {
  final Map<String, dynamic> settings;
  const AdminSettingsLoaded({required this.settings});

  @override
  List<Object?> get props => [settings];
}

class AdminAuditLogsLoaded extends AdminState {
  final List<Map<String, dynamic>> logs;
  final String? nextCursor;
  final bool hasMore;

  const AdminAuditLogsLoaded({
    required this.logs,
    this.nextCursor,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [logs, nextCursor, hasMore];
}

class AdminWithdrawalsLoaded extends AdminState {
  final List<Map<String, dynamic>> withdrawals;
  final String statusFilter;
  final String? nextCursor;

  const AdminWithdrawalsLoaded({
    required this.withdrawals,
    required this.statusFilter,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [withdrawals, statusFilter, nextCursor];
}

class AdminActionSuccess extends AdminState {
  final String message;
  const AdminActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class AdminError extends AdminState {
  final String message;
  final bool isForbidden;

  const AdminError({
    required this.message,
    this.isForbidden = false,
  });

  @override
  List<Object?> get props => [message, isForbidden];
}
