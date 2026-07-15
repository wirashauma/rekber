import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminChatRoomScreen extends StatefulWidget {
  final String txid;

  const AdminChatRoomScreen({super.key, required this.txid});

  @override
  State<AdminChatRoomScreen> createState() => _AdminChatRoomScreenState();
}

class _AdminChatRoomScreenState extends State<AdminChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'Pembeli',
      'text': 'Gan, paketnya kok isinya cuma kardus kosong?',
      'time': '10:00',
      'isAdmin': false,
    },
    {
      'sender': 'Penjual',
      'text': 'Waduh, saya sudah kirim sesuai pesanan mas. Ada video unboxing?',
      'time': '10:05',
      'isAdmin': false,
    },
    {
      'sender': 'Pembeli',
      'text': 'Ada ini, sebentar saya upload.',
      'time': '10:07',
      'isAdmin': false,
    },
    {
      'sender': 'PENGUMUMAN ADMIN',
      'text': 'Admin telah memasuki percakapan. Harap kedua pihak memberikan bukti yang diperlukan.',
      'time': '11:00',
      'isAdmin': true,
    },
  ];

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'sender': 'PENGUMUMAN ADMIN',
        'text': _messageController.text.trim(),
        'time': 'Sekarang',
        'isAdmin': true,
      });
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'INTERVENSI - ${widget.txid}',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── INFO BANNER ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: Text(
              'MODE INTERVENSI: Pesan Anda akan ditandai sebagai PENGUMUMAN RESMI.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.yellowAccent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          // ── CHAT LIST ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),

          // ── INPUT AREA ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.black, width: 3),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellowAccent.withValues(alpha: 0.3),
                        border: Border.all(color: AppColors.black, width: 2),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Tulis pesan admin...',
                          hintStyle: GoogleFonts.spaceGrotesk(color: Colors.grey[600]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  BrutalistBounce(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: AppColors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.grey,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isAdmin = msg['isAdmin'] as bool;
    
    return Column(
      crossAxisAlignment: isAdmin ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (!isAdmin)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              msg['sender'],
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black54,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * (isAdmin ? 0.9 : 0.75),
          ),
          child: BrutalistCard(
            backgroundColor: isAdmin ? Colors.yellowAccent : Colors.white,
            padding: const EdgeInsets.all(12),
            borderRadius: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.black,
                    child: Text(
                      'PENGUMUMAN ADMIN',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Text(
                  msg['text'],
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: isAdmin ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    msg['time'],
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
