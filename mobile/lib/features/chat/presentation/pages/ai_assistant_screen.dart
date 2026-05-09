import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'ai',
      'message': 'Halo! Saya Asisten AI Rekber-App. Ada yang bisa saya bantu hari ini?',
      'time': '12:00',
    },
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'message': text,
        'time': _getCurrentTime(),
      });
    });
    _messageController.clear();
    _scrollToBottom();

    // Simulate AI response
    Future.delayed(const Duration(milliseconds: 1000), () {
      _simulateAiResponse(text);
    });
  }

  void _simulateAiResponse(String query) {
    String response = '';
    
    if (query.contains('Cara Pakai App')) {
      response = 'BERIKUT ADALAH PANDUAN PENGGUNAAN REKBER:\n\n'
          '1. PILIH PRODUK: Cari item yang ingin dibeli.\n'
          '2. BUAT TRANSAKSI: Klik tombol "Beli" dan isi detailnya.\n'
          '3. BAYAR KE REKBER: Transfer ke rekening resmi kami.\n'
          '4. TUNGGU BARANG: Penjual akan mengirim barang setelah dana masuk.\n'
          '5. KONFIRMASI: Selesaikan transaksi jika barang sesuai.';
    } else if (query.contains('Resi')) {
      response = 'ANALISIS GAMBAR: RESI PENGIRIMAN\n\n'
          '🔍 STATUS: VALID\n'
          'CATATAN KEAMANAN: Pastikan nama pengirim sesuai dengan akun penjual.\n'
          'REKOMENDASI: Pantau pergerakan kurir secara berkala melalui menu Lacak.';
    } else {
      response = 'Pesan Anda telah diterima. Saya sedang menganalisis permintaan Anda. Harap tunggu sebentar...';
    }

    setState(() {
      _messages.add({
        'role': 'ai',
        'message': response,
        'time': _getCurrentTime(),
      });
    });
    _scrollToBottom();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final canPop = Navigator.of(context).canPop();
    
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 70,
      shape: const Border(
        bottom: BorderSide(color: AppColors.black, width: 3),
      ),
      leading: canPop 
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => context.pop(),
          )
        : null,
      title: Text(
        'ASISTEN CEPAT AI',
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: AppColors.white,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isAi = msg['role'] == 'ai';
    final messageText = msg['message'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) _buildAvatar(Icons.smart_toy, AppColors.primary, isAi: true),
          if (isAi) const SizedBox(width: 12),
          
          Flexible(
            child: BrutalistCard(
              backgroundColor: isAi ? const Color(0xFFF5F5F5) : Colors.white,
              borderRadius: 0,
              borderWidth: 2.0,
              shadowOffset: const Offset(4, 4),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formatMessage(messageText),
                  const SizedBox(height: 8),
                  Text(
                    msg['time'],
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (!isAi) const SizedBox(width: 12),
          if (!isAi) _buildAvatar(Icons.person, Colors.white, isAi: false),
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color bgColor, {required bool isAi}) {
    return BrutalistCard(
      backgroundColor: bgColor,
      shape: BoxShape.rectangle,
      borderRadius: 4,
      borderWidth: 2,
      shadowOffset: const Offset(2, 2),
      padding: const EdgeInsets.all(4),
      child: Icon(
        icon, 
        color: isAi ? Colors.white : Colors.black, 
        size: 20
      ),
    );
  }

  Widget _formatMessage(String text) {
    if (text.contains('ANALISIS GAMBAR:')) {
      return _buildImageAnalysis(text);
    }

    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: AppColors.black,
        height: 1.4,
      ),
    );
  }

  Widget _buildImageAnalysis(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('ANALISIS GAMBAR:')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.image_search, size: 18, color: AppColors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        } else if (line.startsWith('CATATAN KEAMANAN:')) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.security, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        } else if (line.startsWith('REKOMENDASI:')) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.recommend, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line,
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.success),
                  ),
                ),
              ],
            ),
          );
        }
        return Text(
          line,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
        );
      }).toList(),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 
        16, 
        16, 
        MediaQuery.of(context).padding.bottom + 16
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.black, width: 3),
        ),
      ),
      child: Row(
        children: [
          _buildMultimediaButton(
            icon: Icons.attach_file,
            color: Colors.white,
            onTap: () {
              // Simulate image picking
              _handleSendMessage("[Gambar Dipilih: Struk Pembayaran]");
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.black,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Tanya Asisten AI...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildMultimediaButton(
            icon: Icons.mic,
            color: Colors.white,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildMultimediaButton(
            icon: Icons.send_rounded,
            color: AppColors.primary,
            iconColor: Colors.white,
            onTap: () => _handleSendMessage(_messageController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color iconColor = AppColors.black,
  }) {
    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppColors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
