import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../bloc/chat_bloc.dart';

class ChatRoomPage extends StatefulWidget {
  final String? transactionId;

  const ChatRoomPage({super.key, this.transactionId});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingDebounce;
  bool _isUploadingImage = false;

  late final String _txId;

  @override
  void initState() {
    super.initState();
    _txId = widget.transactionId ?? '';

    if (_txId.isNotEmpty) {
      context.read<ChatBloc>().add(ChatStarted(transactionId: _txId));
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 150) {
        context.read<ChatBloc>().add(ChatLoadMoreRequested(transactionId: _txId));
      }
    }
  }

  void _onTextChanged(String text) {
    _typingDebounce?.cancel();
    context.read<ChatBloc>().add(ChatTypingSent(transactionId: _txId, isTyping: true));

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<ChatBloc>().add(ChatTypingSent(transactionId: _txId, isTyping: false));
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _typingDebounce?.cancel();
    context.read<ChatBloc>().add(ChatTypingSent(transactionId: _txId, isTyping: false));
    context.read<ChatBloc>().add(ChatTextMessageSent(transactionId: _txId, body: text));
    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final api = sl<ApiService>();
      final res = await api.postMultipart(
        '/files',
        fieldName: 'file',
        filePath: picked.path,
        fields: {'purpose': 'CHAT_IMAGE'},
      );

      if (res != null && res['data']?['id'] != null) {
        final fileId = res['data']['id'].toString();
        if (mounted) {
          context.read<ChatBloc>().add(ChatImageMessageSent(
                transactionId: _txId,
                fileId: fileId,
              ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim gambar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _openImageViewer(String fileIdOrUrl) async {
    String displayUrl = fileIdOrUrl;
    if (!fileIdOrUrl.startsWith('http')) {
      try {
        final api = sl<ApiService>();
        final res = await api.get('/files/$fileIdOrUrl/url');
        if (res != null && res['data']?['url'] != null) {
          displayUrl = res['data']['url'];
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  displayUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.black, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RUANG CHAT TRANSAKSI',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'ID: ${_txId.isNotEmpty ? _txId : "Transaksi"}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: AppColors.black, height: 4.0),
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.black));
          }

          final messages = state.messages;
          final isOpponentTyping = state.isOpponentTyping;
          final isLiveConnected = state.isConnected;

          return Column(
            children: [
              // Connection status strip (only if offline/reconnecting)
              if (!isLiveConnected)
                Container(
                  width: double.infinity,
                  color: AppColors.paleYellow,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Menghubungkan ke server realtime...',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Chat Messages List
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(color: AppColors.black, width: 2),
                            boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(4, 4))],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textSecondary),
                              SizedBox(height: 8),
                              Text('Belum ada pesan.', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text(
                                'Percakapan di ruangan ini aman dan dipantau oleh sistem escrow.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          if (msg.isSystem) {
                            return _buildSystemMessage(msg);
                          }
                          final isMe = msg.senderId == currentUserId;
                          return _buildChatMessageItem(msg, isMe);
                        },
                      ),
              ),

              // Opponent Typing Indicator Banner
              if (isOpponentTyping)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.black, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Lawan bicara sedang mengetik... ✍️',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Input Bar
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessageEntity msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            border: Border.all(color: AppColors.black, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(2, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppColors.black),
                  SizedBox(width: 6),
                  Text(
                    'SISTEM ESCROW',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                msg.body ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(msg.createdAt),
                style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessageItem(ChatMessageEntity msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          BrutalistCard(
            backgroundColor: isMe ? const Color(0xFFFFD54F) : AppColors.white,
            borderRadius: 8,
            borderWidth: 2.0,
            shadowOffset: const Offset(3, 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image attachment if type IMAGE
                  if (msg.isImage && msg.fileId != null) ...[
                    GestureDetector(
                      onTap: () => _openImageViewer(msg.fileId!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.black, width: 1.5),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.image_rounded, size: 48, color: AppColors.black),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Icon(Icons.zoom_in_rounded, size: 20, color: AppColors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Text body
                  if (msg.body != null && msg.body!.isNotEmpty)
                    Text(
                      msg.body!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.black,
                      ),
                    ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text(
                        _formatTime(msg.createdAt),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: msg.isRead ? Colors.blue.shade800 : Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.black, width: 2.5)),
      ),
      child: Row(
        children: [
          // Multimedia / Photo Button
          BrutalistBounce(
            onTap: _isUploadingImage ? null : _pickAndSendImage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.black, width: 2.0),
                boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(2, 2))],
              ),
              child: _isUploadingImage
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                  : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.black, size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Message input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.black, width: 2.0),
                boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(2, 2))],
              ),
              child: TextField(
                controller: _messageController,
                onChanged: _onTextChanged,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan...',
                  hintStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          BrutalistBounce(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                border: Border.all(color: AppColors.black, width: 2.0),
                boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(2, 2))],
              ),
              child: const Icon(Icons.send_rounded, color: AppColors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
