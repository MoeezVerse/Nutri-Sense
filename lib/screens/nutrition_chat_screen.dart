import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../services/nutrition_chat_service.dart';
import '../services/food_analysis_service.dart';
import '../widgets/pressable_scale.dart';

class NutritionChatScreen extends StatefulWidget {
  const NutritionChatScreen({super.key});

  @override
  State<NutritionChatScreen> createState() => _NutritionChatScreenState();
}

class _NutritionChatScreenState extends State<NutritionChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  UserProfile? _profile;
  bool _loading = false;
  bool _profileLoaded = false;

  static const int _maxHistoryMessages = 12;
  static const int _maxStoredMessages = 40;

  String? _lastUserMessage;
  bool _lastFailed = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _timeLabel(int timeMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _appendMessage({
    required String role,
    required String text,
    int? timeMs,
  }) {
    final nowMs = timeMs ?? DateTime.now().millisecondsSinceEpoch;
    _messages.add({
      'role': role,
      'text': text,
      'timeMs': nowMs.toString(),
    });

    // Prevent unbounded growth in memory and context.
    if (_messages.length > _maxStoredMessages) {
      _messages.removeRange(0, _messages.length - _maxStoredMessages);
    }
  }

  bool get _canSend {
    final t = _controller.text.trim();
    return t.isNotEmpty && !_loading;
  }

  Future<void> _loadProfile() async {
    final p = await ProfileStorage.load();
    setState(() {
      _profile = p;
      _profileLoaded = true;
      if (_messages.isEmpty) {
        _appendMessage(
          role: 'assistant',
          text: p != null
              ? 'Hi ${p.name}! I\'m your personal nutrition assistant. I have your profile (goal: ${p.goal}, activity: ${p.activityLevel}). Ask me anything about diet, meals, or calories.'
              : 'Hi! I\'m your personal nutrition assistant. Ask me anything about diet, meals, or calories. Add your profile in the app for personalized advice.',
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _lastUserMessage = text;
      _lastFailed = false;
      _appendMessage(role: 'user', text: text);
      _loading = true;
    });
    _scrollToEnd();

    try {
      final end = _messages.length - 1; // exclude the just-added user message
      final start =
          (end - _maxHistoryMessages).clamp(0, end).toInt(); // cap context
      final history = _messages.sublist(start, end);

      final reply = await NutritionChatService.sendMessage(
        userMessage: text,
        history: history,
        profile: _profile,
      );
      if (!mounted) return;
      setState(() {
        _appendMessage(role: 'assistant', text: reply);
        _loading = false;
        _lastFailed = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = e is FoodAnalysisException
          ? e.message
          : 'Could not get a response. Please try again.';
      setState(() {
        _appendMessage(role: 'assistant', text: msg);
        _lastFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
      _scrollToEnd();
    }
  }

  Future<void> _clearChat() async {
    if (_loading) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear chat?'),
          content: const Text('This will remove your messages from this chat.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() {
      _messages.clear();
      _lastUserMessage = null;
      _lastFailed = false;
    });
    await _loadProfile();
    _scrollToEnd();
  }

  Future<void> _retryLast() async {
    if (_loading || !_lastFailed || _lastUserMessage == null) return;
    if (!mounted) return;
    setState(() {
      // Keep the last failure visible until the new request starts.
      _controller.text = _lastUserMessage!;
    });
    await _send();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Assistant'),
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _loading ? null : _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Retry last message',
            onPressed: (_lastFailed && !_loading) ? _retryLast : null,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _profileLoaded
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return _buildBubble(null, 'Thinking...', true);
                      }
                      final m = _messages[i];
                      return _buildBubble(
                        m['role'] ?? 'user',
                        m['text'] ?? '',
                        false,
                        timeMs: int.tryParse(m['timeMs'] ?? '') ?? 0,
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71))),
          ),
          if (_profileLoaded && _messages.length <= 1 && !_loading)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                compact ? 8 : 12,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Meal ideas'),
                    onPressed: () {
                      _controller.text = 'Give me healthy meal ideas for my goal.';
                      _send();
                    },
                  ),
                  ActionChip(
                    label: const Text('Calorie guidance'),
                    onPressed: () {
                      _controller.text = 'How many calories should I eat today?';
                      _send();
                    },
                  ),
                  ActionChip(
                    label: const Text('Protein tips'),
                    onPressed: () {
                      _controller.text = 'How can I increase protein without gaining excess calories?';
                      _send();
                    },
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about diet, meals, calories...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_loading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    child: IconButton.filled(
                      onPressed: _canSend ? _send : null,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Send message',
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

  Widget _buildBubble(String? role, String text, bool isTyping,
      {int timeMs = 0}) {
    final isUser = role == 'user';
    final timeLabel = timeMs > 0 ? _timeLabel(timeMs) : null;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF22C55E) : const Color(0xFFE8ECF0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: isTyping
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Thinking...', style: TextStyle(color: Colors.grey.shade700)),
                ],
              )
            : Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1A1D29),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (timeLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
