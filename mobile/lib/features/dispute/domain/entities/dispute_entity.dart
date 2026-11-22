import 'package:equatable/equatable.dart';

class DisputeEvidenceEntity extends Equatable {
  final String id;
  final String disputeId;
  final String submittedById;
  final String? note;
  final List<String> fileIds;
  final List<String> fileUrls;
  final DateTime createdAt;
  final String? submitterName;

  const DisputeEvidenceEntity({
    required this.id,
    required this.disputeId,
    required this.submittedById,
    this.note,
    this.fileIds = const [],
    this.fileUrls = const [],
    required this.createdAt,
    this.submitterName,
  });

  factory DisputeEvidenceEntity.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null || val is! List) return [];
      return val.map((e) => e.toString()).toList();
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return DisputeEvidenceEntity(
      id: json['id']?.toString() ?? '',
      disputeId: json['disputeId']?.toString() ?? json['dispute_id']?.toString() ?? '',
      submittedById: json['submittedById']?.toString() ?? json['submitted_by_id']?.toString() ?? '',
      note: json['note']?.toString(),
      fileIds: parseList(json['fileIds'] ?? json['file_ids']),
      fileUrls: parseList(json['fileUrls'] ?? json['file_urls']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      submitterName: json['submittedBy']?['fullName'] ?? json['submittedBy']?['name'] ?? json['submitterName'],
    );
  }

  @override
  List<Object?> get props => [id, disputeId, submittedById, note, fileIds, createdAt];
}

class DisputeEntity extends Equatable {
  final String id;
  final String transactionId;
  final String openedById;
  final String reason; // NOT_RECEIVED, NOT_AS_DESCRIBED, DEFECTIVE, OTHER
  final String description;
  final String status; // OPEN, UNDER_REVIEW, RESOLVED_BUYER, RESOLVED_SELLER
  final String? resolutionNote;
  final String? resolvedById;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final List<DisputeEvidenceEntity> evidences;

  const DisputeEntity({
    required this.id,
    required this.transactionId,
    required this.openedById,
    required this.reason,
    required this.description,
    required this.status,
    this.resolutionNote,
    this.resolvedById,
    this.resolvedAt,
    required this.createdAt,
    this.evidences = const [],
  });

  bool get isOpen => status == 'OPEN';
  bool get isUnderReview => status == 'UNDER_REVIEW';
  bool get isResolved => status == 'RESOLVED_BUYER' || status == 'RESOLVED_SELLER';
  bool get canAddEvidence => isOpen || isUnderReview;

  String get reasonLabel {
    switch (reason.toUpperCase()) {
      case 'NOT_RECEIVED':
        return 'Barang Tidak Diterima';
      case 'NOT_AS_DESCRIBED':
        return 'Tidak Sesuai Deskripsi';
      case 'DEFECTIVE':
        return 'Barang Rusak / Cacat';
      case 'OTHER':
        return 'Alasan Lainnya';
      default:
        return reason;
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Sengketa Dibuka';
      case 'UNDER_REVIEW':
        return 'Dalam Peninjauan Admin';
      case 'RESOLVED_BUYER':
        return 'Selesai: Dimenangkan Pembeli';
      case 'RESOLVED_SELLER':
        return 'Selesai: Dimenangkan Penjual';
      default:
        return status;
    }
  }

  factory DisputeEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    List<DisputeEvidenceEntity> parseEvidences(dynamic list) {
      if (list == null || list is! List) return [];
      return list.map((e) => DisputeEvidenceEntity.fromJson(e as Map<String, dynamic>)).toList();
    }

    return DisputeEntity(
      id: json['id']?.toString() ?? '',
      transactionId: json['transactionId']?.toString() ?? json['transaction_id']?.toString() ?? '',
      openedById: json['openedById']?.toString() ?? json['opened_by_id']?.toString() ?? '',
      reason: (json['reason'] ?? 'OTHER').toString().toUpperCase(),
      description: json['description']?.toString() ?? '',
      status: (json['status'] ?? 'OPEN').toString().toUpperCase(),
      resolutionNote: json['resolutionNote']?.toString() ?? json['resolution_note']?.toString(),
      resolvedById: json['resolvedById']?.toString() ?? json['resolved_by_id']?.toString(),
      resolvedAt: parseDate(json['resolvedAt'] ?? json['resolved_at']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      evidences: parseEvidences(json['evidences'] ?? json['DisputeEvidence']),
    );
  }

  @override
  List<Object?> get props => [id, transactionId, status, reason, description, evidences];
}
