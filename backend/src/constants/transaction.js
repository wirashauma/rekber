// =============================================================================
// Transaction Constants & Escrow State Machine Transitions
// =============================================================================

const TRANSACTION_STATUS = {
  PENDING: 'PENDING',
  PAID: 'PAID',
  SHIPPED: 'SHIPPED',
  COMPLETED: 'COMPLETED',
  CANCELLED: 'CANCELLED',
  DISPUTED: 'DISPUTED',
  REFUNDED: 'REFUNDED',
};

const TERMINAL_STATUSES = [
  TRANSACTION_STATUS.COMPLETED,
  TRANSACTION_STATUS.CANCELLED,
  TRANSACTION_STATUS.REFUNDED,
];

// Valid state transitions map
// Key: current status → Value: array of allowed next statuses
const VALID_TRANSITIONS = {
  PENDING: ['PAID', 'CANCELLED'],
  PAID: ['SHIPPED', 'REFUNDED', 'DISPUTED'],
  SHIPPED: ['COMPLETED', 'DISPUTED'],
  DISPUTED: ['COMPLETED', 'REFUNDED'],
  // Terminal states — no further transitions allowed
  COMPLETED: [],
  CANCELLED: [],
  REFUNDED: [],
};

// Transition authority map
// Key: "FROM→TO" → Value: array of allowed roles or actor identifiers
// Roles: 'BUYER', 'SELLER', 'ADMIN', 'SYSTEM'
const TRANSITION_ROLES = {
  'PENDING→PAID': ['BUYER'],
  'PENDING→CANCELLED': ['BUYER', 'SELLER', 'SYSTEM'],
  'PAID→SHIPPED': ['SELLER'],
  'PAID→REFUNDED': ['SELLER', 'ADMIN'],
  'SHIPPED→COMPLETED': ['BUYER', 'SYSTEM'],
  'PAID→DISPUTED': ['BUYER'],
  'SHIPPED→DISPUTED': ['BUYER'],
  'DISPUTED→COMPLETED': ['ADMIN'],
  'DISPUTED→REFUNDED': ['ADMIN'],
};

module.exports = {
  TRANSACTION_STATUS,
  TERMINAL_STATUSES,
  VALID_TRANSITIONS,
  TRANSITION_ROLES,
};
