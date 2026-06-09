import 'package:flutter/material.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/services/ai_service.dart';

class AiInsightsTab extends StatefulWidget {
  const AiInsightsTab({super.key});

  @override
  State<AiInsightsTab> createState() => _AiInsightsTabState();
}

class _AiInsightsTabState extends State<AiInsightsTab> {
  final AiService _aiService = AiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text':
          'Hi, I am your ExpenseAI Financial Advisor. I have analyzed your transactions database and current budget sheets. Ask me any question like:\n- "Can I afford a ₹15,000 phone?"\n- "Should I buy a bike of ₹1,20,000?"\n- "How much should I save monthly?"',
    },
  ];

  bool _isTyping = false;

  void _sendMessage() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': query});
      _queryController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1000));

    final response = _aiService.answerFinancialQuery(query);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({'sender': 'ai', 'text': response});
      });
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
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insights = _aiService.generateInsights();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
                top: 10.0,
                right: 20.0,
              ),
              child: Text(
                'AI Financial intelligence',
                style: AppTextStyles.heading2(isDark: isDark),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: insights.length,
                itemBuilder: (context, index) {
                  final ins = insights[index];
                  return _buildInsightCard(ins, isDark);
                },
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'CHAT WITH ADVISOR AI',
                style: AppTextStyles.caption(
                  isDark: isDark,
                ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  color: isDark
                      ? AppColors.cardDark.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.6),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isTyping) {
                              return _buildTypingIndicator();
                            }
                            final msg = _messages[index];
                            final isAi = msg['sender'] == 'ai';
                            return _buildMessageBubble(msg['text']!, isAi);
                          },
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _queryController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Ask advisor, e.g. "Can I buy a laptop?"',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight, bool isDark) {
    Color accentColor;
    IconData icon;

    switch (insight['type']) {
      case 'warning':
        accentColor = AppColors.accentPink;
        icon = Icons.warning_amber_rounded;
        break;
      case 'success':
        accentColor = AppColors.emeraldGreen;
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        accentColor = AppColors.electricBlue;
        icon = Icons.lightbulb_outline_rounded;
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderOpacity: 0.1,
        customBorder: Border(left: BorderSide(color: accentColor, width: 4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  insight['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight['description'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryDark,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isAi) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAi ? 0 : 16),
            bottomRight: Radius.circular(isAi ? 16 : 0),
          ),
          gradient: isAi
              ? const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                )
              : AppColors.primaryGradient,
        ),
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          color: Color(0xFF1E293B),
        ),
        child: const SizedBox(
          width: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(radius: 2, backgroundColor: Colors.white),
              CircleAvatar(radius: 2, backgroundColor: Colors.white),
              CircleAvatar(radius: 2, backgroundColor: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
