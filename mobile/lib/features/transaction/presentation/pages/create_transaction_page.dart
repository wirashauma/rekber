import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/rekber_button.dart';
import '../../../../core/widgets/rekber_text_field.dart';

/// Create Transaction Page — Buyer initiates a new escrow request
class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _sellerController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _parsedAmount = 0;

  @override
  void dispose() {
    _sellerController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fee = (_parsedAmount * 0.025).round();
    final total = _parsedAmount + fee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buat Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Dana akan ditahan di REKBER hingga Anda mengkonfirmasi penerimaan barang.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xl),

              // Seller email/username
              RekberTextField(
                label: 'Email / Username Penjual',
                hint: 'Masukkan email atau username penjual',
                controller: _sellerController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Penjual wajib diisi' : null,
              ),
              const SizedBox(height: AppDimensions.base),

              // Amount
              RekberTextField(
                label: 'Nominal (Rp)',
                hint: '0',
                controller: _amountController,
                keyboardType: TextInputType.number,
                prefixText: 'Rp ',
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
                  setState(() {
                    _parsedAmount = int.tryParse(value) ?? 0;
                  });
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nominal wajib diisi';
                  final amount = int.tryParse(v) ?? 0;
                  if (amount < 10000) return 'Minimal Rp10.000';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.base),

              // Description
              RekberTextField(
                label: 'Deskripsi Barang / Jasa',
                hint: 'Jelaskan barang atau jasa yang ditransaksikan',
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Deskripsi wajib diisi' : null,
              ),
              const SizedBox(height: AppDimensions.xl),

              // Fee breakdown
              if (_parsedAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.base),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _feeRow('Harga Barang', CurrencyFormatter.format(_parsedAmount)),
                      _feeRow('Biaya Layanan (2.5%)', CurrencyFormatter.format(fee)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Bayar', style: AppTextStyles.labelLarge),
                          Text(
                            CurrencyFormatter.format(total),
                            style: AppTextStyles.currency.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
              ],

              // Submit button
              RekberButton(
                text: 'Lanjut ke Pembayaran',
                icon: Icons.arrow_forward_rounded,
                onPressed: _parsedAmount >= 10000 ? _onSubmit : null,
              ),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: Navigate to payment selection page
    }
  }
}
