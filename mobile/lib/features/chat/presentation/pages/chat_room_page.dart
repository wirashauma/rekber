import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String _currentUserId = 'user_1';

  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'senderId': 'user_2',
      'senderName': 'Toko Elektronik',
      'message': 'Halo gan, barangnya sudah siap dikirim ya.',
      'time': '10:00',
      'status': 3, // Read
    },
    {
      'id': '2',
      'senderId': 'user_1',
      'senderName': 'Me',
      'message': 'Oke siap, tolong dipacking kayu ya biar aman.',
      'time': '10:05',
      'status': 3, // Read
    },
    {
      'id': '3',
      'senderId': 'user_2',
      'senderName': 'Toko Elektronik',
      'message': 'Siap gan, laksanakan! 🚀',
      'time': '10:07',
      'status': 2, // Delivered
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['senderId'] == _currentUserId;
                return _buildChatBubble(msg, isMe);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beli Akun Valorant - Rp450.000',
            style: TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'ID: TRX-9921',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: const [
        SizedBox(width: 16),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                const CircleAvatar(
                  backgroundColor: AppColors.black,
                  radius: 12,
                  child: Icon(Icons.person, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                msg['senderName'],
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: AppColors.black,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  backgroundColor: AppColors.black,
                  radius: 12,
                  child: Icon(Icons.person, size: 14, color: Colors.white),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          BrutalistCard(
            backgroundColor: isMe ? const Color(0xFFFFD54F) : Colors.white,
            borderRadius: 8,
            borderWidth: 2.0,
            shadowOffset: const Offset(3, 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg['message'],
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
                        msg['time'],
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildReadReceipt(msg['status'] ?? 1),
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

  Widget _buildReadReceipt(int status) {
    switch (status) {
      case 2:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case 3:
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      default:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 
        10, 
        16, 
        MediaQuery.of(context).padding.bottom + 10
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.black, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Attachment Button
          _buildMultimediaButton(Icons.add, () {}),
          const SizedBox(width: 8),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.black, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.black,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
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
          
          // Voice Note Button
          _buildMultimediaButton(Icons.mic, () {}, color: const Color(0xFFFFD54F)),
          const SizedBox(width: 8),

          // Send Button
          BrutalistBounce(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFB4E600), // Neon Green
                border: Border.all(color: AppColors.black, width: 2.0),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.black,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: AppColors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppColors.black, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.black, size: 20),
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({
        'id': DateTime.now().toString(),
        'senderId': _currentUserId,
        'senderName': 'Me',
        'message': _messageController.text,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'status': 1, // Sent
      });
      _messageController.clear();
    });

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
}


