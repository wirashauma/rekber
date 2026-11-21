const {
  toSafeNumber,
  parseInteger,
  calculateFee,
  MAX_SAFE_INTEGER_BIGINT,
} = require('../../src/utils/money');

describe('Unit Test: src/utils/money.js', () => {
  describe('toSafeNumber()', () => {
    test('Mengonversi BigInt ke Number dengan benar', () => {
      expect(toSafeNumber(100000n)).toBe(100000);
      expect(toSafeNumber(0n)).toBe(0);
      expect(toSafeNumber(BigInt(Number.MAX_SAFE_INTEGER))).toBe(Number.MAX_SAFE_INTEGER);
    });

    test('Mengembalikan 0 untuk nilai null atau undefined', () => {
      expect(toSafeNumber(null)).toBe(0);
      expect(toSafeNumber(undefined)).toBe(0);
    });

    test('Menolak BigInt yang melampaui batas aman MAX_SAFE_INTEGER', () => {
      const unsafeBigInt = MAX_SAFE_INTEGER_BIGINT + 1n;
      expect(() => toSafeNumber(unsafeBigInt)).toThrow(RangeError);
      expect(() => toSafeNumber(unsafeBigInt)).toThrow('melebihi batas aman MAX_SAFE_INTEGER');
    });

    test('Menolak Number yang bukan safe integer', () => {
      expect(() => toSafeNumber(Number.MAX_SAFE_INTEGER + 10)).toThrow(RangeError);
    });
  });

  describe('parseInteger()', () => {
    test('Sukses melakukan parsing integer valid dari Number, String, dan BigInt', () => {
      expect(parseInteger(50000)).toBe(50000n);
      expect(parseInteger('75000')).toBe(75000n);
      expect(parseInteger(100000n)).toBe(100000n);
      expect(parseInteger(0)).toBe(0n);
    });

    test('Menolak angka desimal / float', () => {
      expect(() => parseInteger(10.5)).toThrow(TypeError);
      expect(() => parseInteger('10.5')).toThrow(TypeError);
      expect(() => parseInteger('10,5')).toThrow(TypeError);
    });

    test('Menolak input non-numerik, string kosong, boolean, null, undefined', () => {
      expect(() => parseInteger(null)).toThrow(TypeError);
      expect(() => parseInteger(undefined)).toThrow(TypeError);
      expect(() => parseInteger(true)).toThrow(TypeError);
      expect(() => parseInteger('')).toThrow(TypeError);
      expect(() => parseInteger('abc')).toThrow(TypeError);
    });

    test('Menolak nilai negatif bila allowNegative=false (default)', () => {
      expect(() => parseInteger(-1000)).toThrow(RangeError);
      expect(() => parseInteger('-5000')).toThrow(RangeError);
      expect(parseInteger(-5000, { allowNegative: true })).toBe(-5000n);
    });

    test('Menerapkan validasi batasan min dan max', () => {
      expect(() => parseInteger(500, { min: 1000 })).toThrow(RangeError);
      expect(() => parseInteger(15000, { max: 10000 })).toThrow(RangeError);
      expect(parseInteger(5000, { min: 1000, max: 10000 })).toBe(5000n);
    });

    test('Menolak nilai yang melampaui MAX_SAFE_INTEGER', () => {
      const huge = MAX_SAFE_INTEGER_BIGINT + 100n;
      expect(() => parseInteger(huge)).toThrow(RangeError);
    });
  });

  describe('calculateFee()', () => {
    test('Perhitungan fee standar 2% dengan minimum Rp 1.000', () => {
      // Transaksi Rp 10.000 -> 2% = Rp 200, terkena minimum fee Rp 1.000
      const feeLow = calculateFee({ amount: 10000n, feePercent: 2, feeMin: 1000 });
      expect(feeLow.totalFee).toBe(1000n);
      expect(feeLow.buyerFee).toBe(500n);
      expect(feeLow.sellerFee).toBe(500n);

      // Transaksi Rp 100.000 -> 2% = Rp 2.000
      const feeStandard = calculateFee({ amount: 100000n, feePercent: 2, feeMin: 1000 });
      expect(feeStandard.totalFee).toBe(2000n);
      expect(feeStandard.buyerFee).toBe(1000n);
      expect(feeStandard.sellerFee).toBe(1000n);
    });

    test('Pembulatan ke atas (ceiling) saat persentase menghasilkan angka pecahan', () => {
      // Transaksi Rp 50.025 * 2% = 1.000,5 -> dibulatkan ke atas menjadi Rp 1.001
      const feeOdd = calculateFee({
        amount: 50025n,
        feePercent: 2,
        feeMin: 1000,
        feePayer: 'SPLIT',
      });
      expect(feeOdd.totalFee).toBe(1001n);
      // Split ganjil: pembeli dibulatkan ke atas Rp 501, penjual Rp 500
      expect(feeOdd.buyerFee).toBe(501n);
      expect(feeOdd.sellerFee).toBe(500n);
      expect(feeOdd.buyerFee + feeOdd.sellerFee).toBe(feeOdd.totalFee);
    });

    test('Alokasi fee berdasarkan feePayer: BUYER, SELLER, SPLIT', () => {
      // BUYER menanggung 100%
      const feeBuyer = calculateFee({ amount: 100000n, feePayer: 'BUYER' });
      expect(feeBuyer.totalFee).toBe(2000n);
      expect(feeBuyer.buyerFee).toBe(2000n);
      expect(feeBuyer.sellerFee).toBe(0n);

      // SELLER menanggung 100%
      const feeSeller = calculateFee({ amount: 100000n, feePayer: 'SELLER' });
      expect(feeSeller.totalFee).toBe(2000n);
      expect(feeSeller.buyerFee).toBe(0n);
      expect(feeSeller.sellerFee).toBe(2000n);

      // SPLIT 50/50
      const feeSplit = calculateFee({ amount: 100000n, feePayer: 'SPLIT' });
      expect(feeSplit.totalFee).toBe(2000n);
      expect(feeSplit.buyerFee).toBe(1000n);
      expect(feeSplit.sellerFee).toBe(1000n);
    });

    test('Menolak persentase fee negatif atau tidak valid', () => {
      expect(() => calculateFee({ amount: 100000n, feePercent: -1 })).toThrow(RangeError);
      expect(() => calculateFee({ amount: 100000n, feePercent: 'invalid' })).toThrow(RangeError);
    });
  });

  describe('BigInt JSON Serializer', () => {
    test('BigInt otomatis di-serialize sebagai Number di JSON.stringify', () => {
      const payload = {
        amount: 250000n,
        balance: 1000000n,
        status: 'PENDING',
      };

      const jsonString = JSON.stringify(payload);
      expect(jsonString).toBe('{"amount":250000,"balance":1000000,"status":"PENDING"}');

      const parsed = JSON.parse(jsonString);
      expect(typeof parsed.amount).toBe('number');
      expect(parsed.amount).toBe(250000);
      expect(typeof parsed.balance).toBe('number');
      expect(parsed.balance).toBe(1000000);
    });
  });
});
