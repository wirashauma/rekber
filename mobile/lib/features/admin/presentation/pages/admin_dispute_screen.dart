import 'package:flutter/material.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDisputeScreen extends StatelessWidget {
  const AdminDisputeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'MODERASI DISPUTE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.white,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _buildDisputeCard(index);
        },
      ),
    );
  }

  Widget _buildDisputeCard(int index) {
    final List<String> reasons = [
      'Barang tidak sesuai deskripsi',
      'Penjual tidak merespon chat',
      'Akun pembeli mencurigakan',
      'Barang rusak saat pengiriman',
      'Komplain paket kosong',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(16),
        borderRadius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BrutalistBadge(
                  text: 'URGENT',
                  backgroundColor: Colors.yellowAccent,
                ),
                Text(
                  'TXID-#${8270 - index}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reasons[index % reasons.length].toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Pembeli:', 'Budi Santoso (@budi88)'),
            _buildInfoRow('Penjual:', 'Toko Elektronik Makmur'),
            _buildInfoRow('Dana Ditahan:', 'Rp 2.500.000', isBold: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BrutalistButton(
                    text: 'MASUK CHAT',
                    backgroundColor: Colors.cyanAccent,
                    height: 45,
                    borderRadius: 4,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrutalistButton(
                    text: 'TINDAKAN',
                    backgroundColor: Colors.orangeAccent,
                    height: 45,
                    borderRadius: 4,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isBold ? Colors.red : AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
