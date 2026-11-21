const settingsService = require('../../src/services/settings.service');
const { resetDb, prisma } = require('../helpers');

describe('Unit Test: src/services/settings.service.js', () => {
  beforeEach(async () => {
    await resetDb();
    settingsService.clearCache();
  });

  test('Mengembalikan nilai default jika tabel platform_settings kosong', async () => {
    const feePercent = await settingsService.getNumber('fee_percent');
    expect(feePercent).toBe(2);

    const feeMin = await settingsService.getNumber('fee_min');
    expect(feeMin).toBe(1000);

    const feePayerDefault = await settingsService.getString('fee_payer_default');
    expect(feePayerDefault).toBe('SPLIT');

    const autoReleaseHours = await settingsService.getNumber('auto_release_hours');
    expect(autoReleaseHours).toBe(72);

    const pendingExpireHours = await settingsService.getNumber('pending_expire_hours');
    expect(pendingExpireHours).toBe(24);

    const withdrawMin = await settingsService.getNumber('withdraw_min');
    expect(withdrawMin).toBe(50000);

    const withdrawFee = await settingsService.getNumber('withdraw_fee');
    expect(withdrawFee).toBe(0);

    const withdrawDailyLimit = await settingsService.getNumber('withdraw_daily_limit');
    expect(withdrawDailyLimit).toBe(10000000);

    const maxTransactionAmount = await settingsService.getNumber('max_transaction_amount');
    expect(maxTransactionAmount).toBe(5000000);

    const maintenanceMode = await settingsService.getBoolean('maintenance_mode');
    expect(maintenanceMode).toBe(false);
  });

  test('Getter bertipe (getNumber, getBoolean, getString) mengembalikan tipe data yang sesuai', async () => {
    await prisma.platformSetting.createMany({
      data: [
        { key: 'custom_number', value: '42' },
        { key: 'custom_bool_true', value: 'true' },
        { key: 'custom_bool_false', value: 'false' },
        { key: 'custom_str', value: 'hello_rekber' },
      ],
    });

    settingsService.clearCache();

    expect(await settingsService.getNumber('custom_number')).toBe(42);
    expect(await settingsService.getBoolean('custom_bool_true')).toBe(true);
    expect(await settingsService.getBoolean('custom_bool_false')).toBe(false);
    expect(await settingsService.getString('custom_str')).toBe('hello_rekber');
  });

  test('Cache TTL 30 detik: pemanggilan kedua mengambil dari memory cache tanpa query ulang', async () => {
    // 1st call: queries database and populates cache
    await settingsService.getAll();

    // Directly insert into DB without invalidating settingsService cache
    await prisma.platformSetting.create({
      data: { key: 'bypassed_key', value: 'bypassed_val' },
    });

    // 2nd call: hits in-memory cache, so bypassed_key is NOT visible yet
    const cached = await settingsService.get('bypassed_key');
    expect(cached).toBeNull();

    // After clearing cache, new value is visible
    settingsService.clearCache();
    const fresh = await settingsService.get('bypassed_key');
    expect(fresh).toBe('bypassed_val');
  });

  test('Metode set() memperbarui database dan menginvalidasi cache seketika', async () => {
    await settingsService.set('fee_percent', '5');

    const updatedValue = await settingsService.getNumber('fee_percent');
    expect(updatedValue).toBe(5);

    // Verify in database directly
    const row = await prisma.platformSetting.findUnique({ where: { key: 'fee_percent' } });
    expect(row.value).toBe('5');
  });
});
