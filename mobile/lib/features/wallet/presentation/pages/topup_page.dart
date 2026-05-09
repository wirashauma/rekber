import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class TopUpPage extends StatelessWidget {
  const TopUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brightBlue,
        title: const Text('TOP UP SALDO', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.black, width: 3)),
        iconTheme: const IconThemeData(color: AppColors.black),
      ),
      body: const Center(
        child: Text('Top Up Screen Placeholder', style: AppTextStyles.h2),
      ),
    );
  }
}
