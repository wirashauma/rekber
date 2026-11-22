import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({super.key});

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  final _feePercentController = TextEditingController();
  final _feeMinController = TextEditingController();
  final _withdrawMinController = TextEditingController();
  final _withdrawFeeController = TextEditingController();
  final _withdrawDailyLimitController = TextEditingController();
  final _maxTransactionAmountController = TextEditingController();
  final _autoReleaseHoursController = TextEditingController();

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadSettings();
  }

  @override
  void dispose() {
    _feePercentController.dispose();
    _feeMinController.dispose();
    _withdrawMinController.dispose();
    _withdrawFeeController.dispose();
    _withdrawDailyLimitController.dispose();
    _maxTransactionAmountController.dispose();
    _autoReleaseHoursController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> settings) {
    if (_isInitialized) return;
    _isInitialized = true;
    _feePercentController.text = (settings['fee_percent'] ?? '2.0').toString();
    _feeMinController.text = (settings['fee_min'] ?? '5000').toString();
    _withdrawMinController.text = (settings['withdraw_min'] ?? '50000').toString();
    _withdrawFeeController.text = (settings['withdraw_fee'] ?? '2500').toString();
    _withdrawDailyLimitController.text =
        (settings['withdraw_daily_limit'] ?? '10000000').toString();
    _maxTransactionAmountController.text =
        (settings['max_transaction_amount'] ?? '50000000').toString();
    _autoReleaseHoursController.text =
        (settings['auto_release_hours'] ?? '48').toString();
  }

  Future<void> _saveAllSettings() async {
    final cubit = context.read<AdminCubit>();

    final feePercent = double.tryParse(_feePercentController.text.trim());
    if (feePercent == null || feePercent < 0 || feePercent > 50) {
      _showError('Fee platform (%) harus berupa angka antara 0 dan 50.');
      return;
    }

    final feeMin = int.tryParse(_feeMinController.text.trim());
    if (feeMin == null || feeMin < 0) {
      _showError('Fee minimum harus berupa bilangan bulat positif.');
      return;
    }

    final withdrawMin = int.tryParse(_withdrawMinController.text.trim());
    if (withdrawMin == null || withdrawMin < 10000) {
      _showError('Batas minimum penarikan minimal Rp 10.000.');
      return;
    }

    final withdrawFee = int.tryParse(_withdrawFeeController.text.trim());
    if (withdrawFee == null || withdrawFee < 0) {
      _showError('Biaya penarikan harus berupa angka positif.');
      return;
    }

    final withdrawDailyLimit = int.tryParse(_withdrawDailyLimitController.text.trim());
    if (withdrawDailyLimit == null || withdrawDailyLimit < withdrawMin) {
      _showError('Batas harian penarikan harus lebih besar dari batas minimum penarikan.');
      return;
    }

    final maxTx = int.tryParse(_maxTransactionAmountController.text.trim());
    if (maxTx == null || maxTx <= 0) {
      _showError('Batas maksimum transaksi tidak valid.');
      return;
    }

    final autoRelease = int.tryParse(_autoReleaseHoursController.text.trim());
    if (autoRelease == null || autoRelease < 1 || autoRelease > 720) {
      _showError('Jam rilis otomatis harus antara 1 dan 720 jam.');
      return;
    }

    // Update settings
    await cubit.updateSetting('fee_percent', feePercent.toString());
    await cubit.updateSetting('fee_min', feeMin.toString());
    await cubit.updateSetting('withdraw_min', withdrawMin.toString());
    await cubit.updateSetting('withdraw_fee', withdrawFee.toString());
    await cubit.updateSetting('withdraw_daily_limit', withdrawDailyLimit.toString());
    await cubit.updateSetting('max_transaction_amount', maxTx.toString());
    await cubit.updateSetting('auto_release_hours', autoRelease.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seluruh pengaturan finansial berhasil diperbarui.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.tealGreen,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KONTROL FINANSIAL',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminSettingsLoaded) {
            _populateFields(state.settings);
          } else if (state is AdminError) {
            _showError(state.message);
          }
        },
        builder: (context, state) {
          if (state is AdminLoading && !_isInitialized) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  BrutalSkeleton(width: double.infinity, height: 60),
                  SizedBox(height: 16),
                  BrutalSkeleton(width: double.infinity, height: 60),
                  SizedBox(height: 16),
                  BrutalSkeleton(width: double.infinity, height: 60),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _isInitialized = false;
              await context.read<AdminCubit>().loadSettings();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PENGATURAN BIAYA & LIMIT TRANSAKSI',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Fee Platform (%)'),
                  BrutalistTextField(
                    controller: _feePercentController,
                    hintText: 'Contoh: 2.0',
                    prefixIcon: Icons.percent_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Fee Minimum Transaksi (Rp)'),
                  BrutalistTextField(
                    controller: _feeMinController,
                    hintText: 'Contoh: 5000',
                    prefixIcon: Icons.money_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Batas Maksimum Nominal Transaksi (Rp)'),
                  BrutalistTextField(
                    controller: _maxTransactionAmountController,
                    hintText: 'Contoh: 50000000',
                    prefixIcon: Icons.account_balance_wallet_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Batas Minimum Penarikan Saldo (Rp)'),
                  BrutalistTextField(
                    controller: _withdrawMinController,
                    hintText: 'Contoh: 50000',
                    prefixIcon: Icons.arrow_downward_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Biaya Penarikan Dana Payout (Rp)'),
                  BrutalistTextField(
                    controller: _withdrawFeeController,
                    hintText: 'Contoh: 2500',
                    prefixIcon: Icons.receipt_long_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Batas Harian Penarikan Per User (Rp)'),
                  BrutalistTextField(
                    controller: _withdrawDailyLimitController,
                    hintText: 'Contoh: 10000000',
                    prefixIcon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Waktu Otomatis Rilis Dana Selesai (Jam)'),
                  BrutalistTextField(
                    controller: _autoReleaseHoursController,
                    hintText: 'Contoh: 48 (2 hari)',
                    prefixIcon: Icons.timer_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 36),

                  BrutalistButton(
                    text: 'SIMPAN PERUBAHAN FINANSIAL',
                    backgroundColor: Colors.yellowAccent,
                    textColor: AppColors.black,
                    onPressed: _saveAllSettings,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.black,
        ),
      ),
    );
  }
}
