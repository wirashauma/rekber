import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_message_entity.dart';
import '../../../chat/presentation/bloc/chat_bloc.dart';

class AdminChatRoomScreen extends StatefulWidget {
  final String txid;

  const AdminChatRoomScreen({super.key, required this.txid});

  @override
  State<AdminChatRoomScreen> createState() => _AdminChatRoomScreenState();
}

class _AdminChatRoomScreenState extends State<AdminChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatStarted(transactionId: widget.txid));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 150) {
        context.read<ChatBloc>().add(ChatLoadMoreRequested(transactionId: widget.txid));
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatBloc>().add(ChatTextMessageSent(
          transactionId: widget.txid,
          body: text,
        ));
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = () {
      final auth = context.read<AuthBloc>().state;
      return auth is AuthAuthenticated ? auth.user.id : null;
    }();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'INSPEKSI - ${widget.txid}',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── INFO BANNER ADMIN ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black,
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.yellowAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MODE INSPEKSI ADMIN: Pengawasan percakapan sengketa realtime.',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.yellowAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── REALTIME CHAT LIST FROM CHAT BLOC ──
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state.isLoading && state.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        state.errorMessage ?? 'Gagal memuat pesan sengketa.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }

                final messages = state.messages;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada percakapan dalam transaksi ini.',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                final hasMore = state.nextCursor != null;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final msg = messages[index];
                    return _buildMessageItem(msg, currentUserId);
                  },
                );
              },
            ),
          ),

          // ── INPUT PESAN ADMIN ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.black, width: 2.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellowAccent.withValues(alpha: 0.25),
                        border: Border.all(color: AppColors.black, width: 2),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Kirim pengumuman/arahan admin...',
                          hintStyle: GoogleFonts.spaceGrotesk(color: Colors.grey[600], fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BrutalistBounce(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  Widget _buildMessageItem(ChatMessageEntity msg, String? currentUserId) {
    if (msg.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: AppColors.black, width: 1.5),
        ),
        child: Text(
          '[SISTEM] ${msg.body ?? ""}',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
      );
    }

    final isMe = currentUserId != null && msg.senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.yellowAccent : AppColors.white,
          border: Border.all(color: AppColors.black, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? 'ADMIN' : (msg.senderName ?? 'User'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isMe ? Colors.red[900] : Colors.blue[900],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.body ?? '',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
