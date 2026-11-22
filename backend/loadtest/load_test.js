// =============================================================================
// k6 Load Test Script: 50 Virtual Users over 5 minutes (Prompt 19 Deliverable 4)
// Mixed user scenario: Login, List transactions, Detail view, Create transaction.
// Run with: k6 run backend/loadtest/load_test.js
// =============================================================================

import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:5000/api';

export const options = {
  stages: [
    { duration: '30s', target: 20 }, // Ramp-up to 20 VUs
    { duration: '1m', target: 50 },  // Ramp-up to 50 VUs
    { duration: '3m', target: 50 },  // Steady state 50 VUs
    { duration: '30s', target: 0 },  // Ramp-down to 0 VUs
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete within 500ms
    http_req_failed: ['rate<0.01'],    // Error rate must be less than 1%
  },
};

export function setup() {
  // Pre-seed a test user and obtain authentication token
  const email = `k6_runner_${Date.now()}@example.com`;
  const password = 'Password123!';

  const regRes = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      name: 'K6 Load Runner',
      email,
      password,
    }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  let token = null;
  if (regRes.status === 201) {
    token = regRes.json('data.accessToken');
  } else {
    const loginRes = http.post(
      `${BASE_URL}/auth/login`,
      JSON.stringify({ email, password }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    token = loginRes.json('data.accessToken');
  }

  // Pre-seed a seller for transaction creation
  const sellerEmail = `k6_seller_${Date.now()}@example.com`;
  const sellerRes = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      name: 'K6 Seller Partner',
      email: sellerEmail,
      password,
    }),
    { headers: { 'Content-Type': 'application/json' } }
  );

  const sellerId = sellerRes.json('data.user.id');

  return { token, sellerId };
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${data.token}`,
  };

  // 1. Fetch user profile / wallet summary (GET /wallet)
  const walletRes = http.get(`${BASE_URL}/wallet`, { headers });
  check(walletRes, {
    'wallet status is 200': (r) => r.status === 200,
  });

  sleep(1);

  // 2. List transactions (GET /transactions)
  const listRes = http.get(`${BASE_URL}/transactions`, { headers });
  check(listRes, {
    'transactions status is 200': (r) => r.status === 200,
  });

  sleep(1);

  // 3. Create a transaction (POST /transactions)
  if (data.sellerId) {
    const createRes = http.post(
      `${BASE_URL}/transactions`,
      JSON.stringify({
        sellerId: data.sellerId,
        amount: 150000,
        itemDescription: 'Load Test Virtual Item',
        feePayer: 'BUYER',
      }),
      { headers }
    );

    const isCreated = check(createRes, {
      'create tx status is 201': (r) => r.status === 201,
    });

    if (isCreated) {
      const txId = createRes.json('data.id');
      // 4. View transaction details (GET /transactions/:id)
      const detailRes = http.get(`${BASE_URL}/transactions/${txId}`, { headers });
      check(detailRes, {
        'detail tx status is 200': (r) => r.status === 200,
      });
    }
  }

  sleep(2);
}
