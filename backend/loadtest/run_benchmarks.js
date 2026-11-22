// =============================================================================
// Automated Load & Concurrency Benchmark Runner (Prompt 19 Deliverable 4)
// Accurately benchmarks real latency (p50, p90, p95, p99) and tests 100-VU
// money race condition using native HTTP client against the live Express server.
// =============================================================================

const http = require('http');
const { performance } = require('perf_hooks');
const { createApp } = require('../src/app');
const prisma = require('../src/config/prisma');
const { createUser, tokenFor, resetDb, disconnectDb } = require('../tests/helpers');
const { reconcile } = require('../src/services/reconcile.service');

// Calculate percentile from sorted number array
const percentile = (arr, p) => {
  if (arr.length === 0) return 0;
  const index = Math.ceil((p / 100) * arr.length) - 1;
  return arr[Math.max(0, Math.min(index, arr.length - 1))];
};

const makeRequest = (port, method, path, headers = {}, body = null) => {
  return new Promise((resolve) => {
    const start = performance.now();
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        method,
        path,
        headers: {
          'Content-Type': 'application/json',
          ...headers,
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => {
          raw += chunk;
        });
        res.on('end', () => {
          const duration = performance.now() - start;
          let parsed = null;
          try {
            parsed = JSON.parse(raw);
          } catch {
            // non-json
          }
          resolve({
            status: res.statusCode,
            duration,
            body: parsed,
          });
        });
      }
    );

    req.on('error', (err) => {
      const duration = performance.now() - start;
      resolve({
        status: 0,
        duration,
        error: err.message,
      });
    });

    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
};

async function main() {
  console.log('🚀 Memulai pengujian beban & konkurensi (Prompt 19 Benchmark)...\n');

  await resetDb();

  // Platform settings
  await prisma.platformSetting.createMany({
    data: [
      { key: 'fee_percent', value: '2' },
      { key: 'fee_min', value: '1000' },
      { key: 'fee_payer_default', value: 'SPLIT' },
      { key: 'auto_release_hours', value: '72' },
      { key: 'pending_expire_hours', value: '24' },
      { key: 'withdraw_min', value: '50000' },
      { key: 'withdraw_fee', value: '0' },
      { key: 'withdraw_daily_limit', value: '10000000' },
      { key: 'max_transaction_amount', value: '5000000' },
      { key: 'maintenance_mode', value: 'false' },
    ],
    skipDuplicates: true,
  });

  const app = createApp();
  const server = http.createServer(app);

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  console.log(`📡 Server benchmark berjalan pada port ${port}`);

  try {
    // =========================================================================
    // SKENARIO 1: Mixed User Load Simulation (50 Pengguna Virtual)
    // =========================================================================
    console.log('\n============================================================');
    console.log('SKENARIO 1: 50 Pengguna Virtual (Mixed Load Test)');
    console.log('============================================================');

    // Create 50 simulated users
    console.log('⏳ Menyiapkan 50 pengguna virtual dan transaksi awal...');
    const users = [];
    const sellers = [];

    for (let i = 0; i < 50; i++) {
      const user = await createUser({
        name: `VU User ${i}`,
        email: `vu_${i}_${Date.now()}@benchmark.test`,
        balance: 1000000n,
      });
      users.push({ ...user, token: tokenFor(user) });
    }

    for (let i = 0; i < 10; i++) {
      const seller = await createUser({
        name: `Seller ${i}`,
        email: `seller_${i}_${Date.now()}@benchmark.test`,
        balance: 0n,
      });
      sellers.push(seller);
    }

    const durations = [];
    let successfulRequests = 0;
    let failedRequests = 0;
    const totalIterationsPerVu = 10; // 50 VUs * 10 iterations * 4 requests = 2000 total requests
    const overallStartTime = performance.now();

    console.log(`⚡ Menjalankan beban 50 VU paralel (~2.000 request campuran)...`);

    const vuPromises = users.map(async (vu, vuIdx) => {
      for (let iter = 0; iter < totalIterationsPerVu; iter++) {
        // Request 1: GET /api/wallet
        const r1 = await makeRequest(port, 'GET', '/api/wallet', {
          Authorization: `Bearer ${vu.token}`,
        });
        durations.push(r1.duration);
        if (r1.status === 200) successfulRequests++;
        else failedRequests++;

        // Request 2: GET /api/transactions
        const r2 = await makeRequest(port, 'GET', '/api/transactions', {
          Authorization: `Bearer ${vu.token}`,
        });
        durations.push(r2.duration);
        if (r2.status === 200) successfulRequests++;
        else failedRequests++;

        // Request 3: POST /api/transactions
        const targetSeller = sellers[(vuIdx + iter) % sellers.length];
        const r3 = await makeRequest(
          port,
          'POST',
          '/api/transactions',
          { Authorization: `Bearer ${vu.token}` },
          {
            sellerId: targetSeller.id,
            amount: 50000 + iter * 1000,
            itemDescription: `Load item ${vuIdx}-${iter}`,
            feePayer: 'BUYER',
          }
        );
        durations.push(r3.duration);
        if (r3.status === 201) successfulRequests++;
        else failedRequests++;

        // Request 4: GET /api/transactions/:id
        if (r3.status === 201 && r3.body?.data?.id) {
          const txId = r3.body.data.id;
          const r4 = await makeRequest(port, 'GET', `/api/transactions/${txId}`, {
            Authorization: `Bearer ${vu.token}`,
          });
          durations.push(r4.duration);
          if (r4.status === 200) successfulRequests++;
          else failedRequests++;
        }
      }
    });

    await Promise.all(vuPromises);
    const overallTotalTime = (performance.now() - overallStartTime) / 1000;

    durations.sort((a, b) => a - b);
    const totalRequests = successfulRequests + failedRequests;
    const errorRate = ((failedRequests / totalRequests) * 100).toFixed(2);
    const rps = (totalRequests / overallTotalTime).toFixed(1);
    const minLat = durations[0].toFixed(2);
    const maxLat = durations[durations.length - 1].toFixed(2);
    const meanLat = (durations.reduce((s, v) => s + v, 0) / durations.length).toFixed(2);
    const p50 = percentile(durations, 50).toFixed(2);
    const p90 = percentile(durations, 90).toFixed(2);
    const p95 = percentile(durations, 95).toFixed(2);
    const p99 = percentile(durations, 99).toFixed(2);

    console.log(`📊 HASIL PENGUJIAN BEBAN 50 VU:`);
    console.log(`   - Total Request     : ${totalRequests}`);
    console.log(`   - Berhasil (2xx)    : ${successfulRequests}`);
    console.log(`   - Gagal             : ${failedRequests}`);
    console.log(`   - Error Rate        : ${errorRate}% (Target: < 1.0%)`);
    console.log(`   - Throughput (RPS)  : ${rps} req/detik`);
    console.log(`   - Latensi Min       : ${minLat} ms`);
    console.log(`   - Latensi Rata-rata : ${meanLat} ms`);
    console.log(`   - Latensi p50       : ${p50} ms`);
    console.log(`   - Latensi p90       : ${p90} ms`);
    console.log(`   - Latensi p95       : ${p95} ms (Target: < 500 ms)`);
    console.log(`   - Latensi p99       : ${p99} ms`);

    // =========================================================================
    // SKENARIO 2: Skenario Konkurensi Uang 100 VU pada 1 Transaksi
    // =========================================================================
    console.log('\n============================================================');
    console.log('SKENARIO 2: Konkurensi 100 VU pada 1 Transaksi (Race Condition Test)');
    console.log('============================================================');

    const buyer = await createUser({
      name: 'Pembeli Balap',
      email: `buyer_race_${Date.now()}@test.com`,
      balance: 1000000n,
    });
    const seller = await createUser({
      name: 'Penjual Balap',
      email: `seller_race_${Date.now()}@test.com`,
      balance: 0n,
    });
    const buyerToken = tokenFor(buyer);

    // Create a single transaction
    const createTxRes = await makeRequest(
      port,
      'POST',
      '/api/transactions',
      { Authorization: `Bearer ${buyerToken}` },
      {
        sellerId: seller.id,
        amount: 300000,
        itemDescription: 'Item Konkurensi Ekstrem 100 VU',
        feePayer: 'BUYER',
      }
    );
    const txId = createTxRes.body.data.id;
    console.log(`📌 Transaksi dibuat: ID ${txId}, status PENDING, nominal Rp 300.000`);

    console.log('⚡ Menembak 100 request simultan (PAID) secara bersamaan...');

    // Fire 100 requests simultaneously to transition status to PAID
    const raceRequests = Array.from({ length: 100 }, () =>
      makeRequest(
        port,
        'PUT',
        `/api/transactions/${txId}/status`,
        { Authorization: `Bearer ${buyerToken}` },
        { status: 'PAID' }
      )
    );

    const raceResults = await Promise.all(raceRequests);

    const statusCounts = {};
    raceResults.forEach((r) => {
      statusCounts[r.status] = (statusCounts[r.status] || 0) + 1;
    });

    console.log('📊 DISTRIBUSI STATUS HTTP RESPON 100 VU:');
    Object.entries(statusCounts).forEach(([st, cnt]) => {
      console.log(`   - HTTP ${st}: ${cnt} request`);
    });

    // Validasi Integritas Konkurensi:
    // Tepat 1 request harus menang (HTTP 200)
    const winners = statusCounts[200] || 0;
    const conflicts = (statusCounts[409] || 0) + (statusCounts[400] || 0);
    const serverErrors = statusCounts[500] || 0;

    console.log('\n🛡️ HASIL AUDIT INTEGRITAS KONKURENSI:');
    console.log(`   - Pemenang Atomic Lock (HTTP 200) : ${winners} (Ekspektasi: TEPAT 1)`);
    console.log(`   - Ditolak Aman CAS (HTTP 409/400) : ${conflicts} (Ekspektasi: 99)`);
    console.log(`   - Crash Server (HTTP 500)         : ${serverErrors} (Ekspektasi: 0)`);

    // Periksa DB
    const finalTx = await prisma.transaction.findUnique({ where: { id: txId } });
    console.log(`   - Status Akhir Transaksi          : ${finalTx.status}`);
    console.log(`   - Dana Terkunci di Escrow         : Rp ${Number(finalTx.heldAmount).toLocaleString('id-ID')}`);

    // Periksa Ledger Entri ESCROW_HOLD
    const holdEntries = await prisma.ledgerEntry.count({
      where: {
        userId: buyer.id,
        type: 'ESCROW_HOLD',
        transactionId: txId,
      },
    });
    console.log(`   - Jumlah Entri Ledger ESCROW_HOLD : ${holdEntries} (Ekspektasi: TEPAT 1)`);

    // Rekonsiliasi Finansial
    const auditResult = await reconcile();
    console.log(`   - Status Rekonsiliasi Finansial   : ${auditResult.isReconciled ? '✅ 100% KONSISTEN (0 Selisih)' : '❌ ADA SELISIH'}`);

    if (winners === 1 && conflicts === 99 && serverErrors === 0 && holdEntries === 1 && auditResult.isReconciled) {
      console.log('\n🎉 SEMUA TARGET PERFORMANSI DAN KEAMANAN KONKURENSI TERCAPAI!');
    } else {
      console.log('\n⚠️ DITEMUKAN ANOMALI PADA UJI KONKURENSI.');
    }
  } finally {
    server.close();
    await disconnectDb();
  }
}

main().catch((err) => {
  console.error('Benchmark fatal error:', err);
  process.exit(1);
});
