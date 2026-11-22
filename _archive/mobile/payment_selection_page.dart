import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/rekber_button.dart';

/// Payment Selection Page — Multi-payment method UI
/// Supports Virtual Account, QRIS, and E-Wallet
class PaymentSelectionPage extends StatefulWidget {
  const PaymentSelectionPage({super.key});

  @override
  State<PaymentSelectionPage> createState() => _PaymentSelectionPageState();
}

class _PaymentSelectionPageState extends State<PaymentSelectionPage> {
  String? _selectedMethod;
  String? _selectedProvider;
  final int _totalAmount = 2562500; // Mock: 2,500,000 + 62,500 fee

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pilih Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount card
                  _buildAmountCard(),
                  const SizedBox(height: AppDimensions.xl),

                  // Virtual Account section
                  _buildSectionTitle('Transfer Bank (Virtual Account)'),
                  const SizedBox(height: AppDimensions.md),
                  _buildVAOptions(),
                  const SizedBox(height: AppDimensions.xl),

                  // QRIS
                  _buildSectionTitle('QRIS'),
                  const SizedBox(height: AppDimensions.md),
                  _buildPaymentOption(
                    method: 'qris',
                    provider: 'qris',
                    icon: Icons.qr_code_2_rounded,
                    title: 'QRIS',
                    subtitle: 'Scan QR untuk bayar dari e-wallet/m-banking',
                    iconColor: AppColors.info,
                  ),
                  const SizedBox(height: AppDimensions.xl),

                  // E-Wallets
                  _buildSectionTitle('E-Wallet'),
                  const SizedBox(height: AppDimensions.md),
                  _buildEWalletOptions(),
                ],
              ),
            ),
          ),

          // Bottom CTA
          _buildBottomCTA(),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Pembayaran',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(_totalAmount),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Batas waktu: 24 jam',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
    );
  }

  Widget _buildVAOptions() {
    final banks = [
      {'code': 'bca', 'name': 'BCA', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFF003D79)},
      {'code': 'bni', 'name': 'BNI', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFFFF6600)},
      {'code': 'bri', 'name': 'BRI', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFF00529C)},
      {'code': 'mandiri', 'name': 'Mandiri', 'icon': Icons.account_balance_rounded, 'color': const Color(0xFF003868)},
    ];

    return Column(
      children: banks.map((bank) {
        return _buildPaymentOption(
          method: 'virtual_account',
          provider: bank['code'] as String,
          icon: bank['icon'] as IconData,
          title: bank['name'] as String,
          subtitle: 'Transfer via Virtual Account ${bank['name']}',
          iconColor: bank['color'] as Color,
        );
      }).toList(),
    );
  }

  Widget _buildEWalletOptions() {
    final wallets = [
      {'code': 'gopay', 'name': 'GoPay', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF00AED6)},
      {'code': 'ovo', 'name': 'OVO', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF4C3494)},
      {'code': 'dana', 'name': 'DANA', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF108EE9)},
      {'code': 'shopeepay', 'name': 'ShopeePay', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFFEE4D2D)},
    ];

    return Column(
      children: wallets.map((wallet) {
        return _buildPaymentOption(
          method: 'ewallet',
          provider: wallet['code'] as String,
          icon: wallet['icon'] as IconData,
          title: wallet['name'] as String,
          subtitle: 'Bayar via ${wallet['name']}',
          iconColor: wallet['color'] as Color,
        );
      }).toList(),
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required String provider,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    final isSelected = _selectedMethod == method && _selectedProvider == provider;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _selectedProvider = provider;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
        padding: const EdgeInsets.all(AppDimensions.base),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 6 : 1.5,
                ),
                color: isSelected ? AppColors.primarySurface : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCTA() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.xl,
        AppDimensions.base,
        AppDimensions.xl,
        MediaQuery.of(context).padding.bottom + AppDimensions.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: RekberButton(
        text: 'Bayar Sekarang',
        icon: Icons.lock_rounded,
        onPressed: _selectedMethod != null
            ? () {
                // TODO: Process payment via Edge Function
              }
            : null,
      ),
    );
  }
}
