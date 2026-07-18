import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int contractId;
  const ChatScreen({super.key, required this.contractId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  final List<String> _suggestedQuestions = [
    '¿Qué significa esta cláusula?',
    'Explícamela como si tuviera quince años',
    '¿Qué pasa si dejo de pagar?',
    '¿Existe otra forma de redactarla?',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService.getChatHistory(widget.contractId);
      setState(() => _messages = history);
    } catch (_) {
      // Si falla el historial, simplemente empieza una conversación nueva
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _controller.clear();

    setState(() {
      _messages = [..._messages, ChatMessage(role: 'user', content: text, createdAt: DateTime.now())];
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.sendChatMessage(widget.contractId, text);
      setState(() => _messages = [..._messages, reply]);
    } catch (e) {
      setState(() => _messages = [
            ..._messages,
            ChatMessage(role: 'assistant', content: 'Error: $e', createdAt: DateTime.now()),
          ]);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregúntale a LEXIA'),
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildBubble(_messages[index]),
                      ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Pregúntame lo que quieras sobre este contrato',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestedQuestions.map((q) {
              return ActionChip(label: Text(q), onPressed: () => _send(q));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2E8B57) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF2E8B57),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _send(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
