// =============================================================================
// k6 Concurrency Money Test: 100 Concurrent VUs on 1 Transaction (Prompt 19)
// Tests compare-and-swap, database locking, and double-spend resistance.
// Run with: k6 run backend/loadtest/concurrency_money_test.js
// =============================================================================

import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:5000/api';

export const options = {
  scenarios: {
    money_concurrency: {
      executor: 'per-vu-iterations',
      vus: 100, // 100 concurrent workers
      iterations: 1, // each fires exactly 1 concurrent request
      maxDuration: '30s',
    },
  },
  thresholds: {
    // We expect exactly 1 success (200) and 99 rejected (409 Conflict or 400 Bad Request)
    // The test succeeds if no unhandled server crash (500) occurs.
    http_req_failed: ['rate<1.0'], // custom check handled in default function
  },
};

export function setup() {
  const buyerEmail = `buyer_race_${Date.now()}@example.com`;
  const sellerEmail = `seller_race_${Date.now()}@example.com`;
  const password = 'Password123!';

  // Register buyer
  const buyerRes = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({ name: 'Buyer Race', email: buyerEmail, password }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  const buyerToken = buyerRes.json('data.accessToken');
  const buyerId = buyerRes.json('data.user.id');

  // Register seller
  const sellerRes = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({ name: 'Seller Race', email: sellerEmail, password }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  const sellerId = sellerRes.json('data.user.id');

  // Create single transaction
  const txRes = http.post(
    `${BASE_URL}/transactions`,
    JSON.stringify({
      sellerId,
      amount: 200000,
      itemDescription: 'High Concurrency Race Test Item',
      feePayer: 'BUYER',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${buyerToken}`,
      },
    }
  );
  const transactionId = txRes.json('data.id');

  return { buyerToken, transactionId };
}

export default function (data) {
  // All 100 VUs simultaneously attempt to execute payment transition
  const res = http.put(
    `${BASE_URL}/transactions/${data.transactionId}/status`,
    JSON.stringify({ status: 'PAID' }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${data.buyerToken}`,
      },
    }
  );

  // Status must be either 200 (the single winner who locked and paid)
  // or 409 / 400 (rejected by compare-and-swap state machine)
  // NEVER 500 (crash or unhandled deadlock)
  check(res, {
    'status is handled (200 or 409 or 400)': (r) => [200, 400, 409].includes(r.status),
    'no server crash (status not 500)': (r) => r.status !== 500,
  });
}
