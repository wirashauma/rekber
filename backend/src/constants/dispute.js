// =============================================================================
// Dispute Constants & Enums
// =============================================================================

const DISPUTE_REASON = {
  NOT_RECEIVED: 'NOT_RECEIVED',
  NOT_AS_DESCRIBED: 'NOT_AS_DESCRIBED',
  DEFECTIVE: 'DEFECTIVE',
  OTHER: 'OTHER',
};

const DISPUTE_STATUS = {
  OPEN: 'OPEN',
  UNDER_REVIEW: 'UNDER_REVIEW',
  RESOLVED_BUYER: 'RESOLVED_BUYER',
  RESOLVED_SELLER: 'RESOLVED_SELLER',
};

const DISPUTE_DECISION = {
  RELEASE_TO_SELLER: 'RELEASE_TO_SELLER',
  REFUND_TO_BUYER: 'REFUND_TO_BUYER',
};

const MAX_EVIDENCE_PER_PARTY = 10;

module.exports = {
  DISPUTE_REASON,
  DISPUTE_STATUS,
  DISPUTE_DECISION,
  MAX_EVIDENCE_PER_PARTY,
};
