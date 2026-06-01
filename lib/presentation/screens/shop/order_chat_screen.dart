import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/djassa_theme.dart';
import '../../../data/services/order_chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({
    super.key,
    required this.orderId,
    this.orderNumber,
  });

  final String orderId;
  final String? orderNumber;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final Future<OrderConversation> _conversationFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _conversationFuture = ref
        .read(orderChatServiceProvider)
        .ensureClientVendorConversation(orderId: widget.orderId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(OrderConversation conversation) async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(orderChatServiceProvider).sendMessage(
            conversationId: conversation.id,
            body: body,
          );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message impossible: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authNotifierProvider).user?.id ?? '';

    return Scaffold(
      backgroundColor: DjassaTheme.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: DjassaTheme.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: FutureBuilder<OrderConversation>(
          future: _conversationFuture,
          builder: (context, snapshot) {
            final number = widget.orderNumber?.trim().isNotEmpty == true
                ? widget.orderNumber!.trim()
                : snapshot.data?.orderNumber ?? 'Commande';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discussion commande'),
                Text(
                  number,
                  style: const TextStyle(
                    color: DjassaTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<OrderConversation>(
        future: _conversationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ChatError(
              message: '${snapshot.error ?? 'Discussion introuvable.'}',
            );
          }

          final conversation = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<OrderChatMessage>>(
                  stream: ref
                      .read(orderChatServiceProvider)
                      .watchMessages(conversation.id),
                  builder: (context, messagesSnapshot) {
                    final messages = messagesSnapshot.data ?? const [];
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );

                    if (messagesSnapshot.hasError) {
                      return _ChatError(message: '${messagesSnapshot.error}');
                    }
                    if (messages.isEmpty) {
                      return const _EmptyChat();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                sending: _sending,
                onSend: () => _send(conversation),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: DjassaTheme.primaryWhite,
          border: Border(top: BorderSide(color: DjassaTheme.borderLight)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ecrire un message...',
                  filled: true,
                  fillColor: DjassaTheme.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: DjassaTheme.accentOrange,
                foregroundColor: DjassaTheme.primaryWhite,
              ),
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  final OrderChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: isMine ? DjassaTheme.primaryBlack : DjassaTheme.primaryWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: DjassaTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color:
                    isMine ? DjassaTheme.primaryWhite : DjassaTheme.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isMine
                    ? DjassaTheme.primaryWhite.withValues(alpha: .58)
                    : DjassaTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: DjassaTheme.accentOrange.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: DjassaTheme.accentOrange,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Demarrez la discussion',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Client et vendeur peuvent s organiser ici autour de cette commande.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DjassaTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }
}
