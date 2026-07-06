import 'package:flutter/material.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/services/ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dashboard_provider.dart';
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';

class AiInsightsTab extends ConsumerStatefulWidget {
  const AiInsightsTab({super.key});

  @override
  ConsumerState<AiInsightsTab> createState() => _AiInsightsTabState();
}

class _AiInsightsTabState extends ConsumerState<AiInsightsTab> {
  final AiService _aiService = AiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text':
          'Hi, I am your ExpenseMate Financial Advisor. I have analyzed your transactions database and current budget sheets. Ask me any question like:\n- "Can I eat biryani today?"\n- "Can I buy shoes?"\n- "Should I buy a bike of ₹1,20,000?"\n- "Can I go to Goa?"',
    },
  ];

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeWelcomeMessage();
  }

  void _initializeWelcomeMessage() {
    final settingsBox = Hive.box(HiveHelper.settingsBox);
    final rawName = settingsBox.get('user_name', defaultValue: 'User') as String;
    final userName = rawName.split(' ').first;

    setState(() {
      _messages[0]['text'] =
          'Hi $userName, I am your ExpenseMate Financial Advisor. I have analyzed your transactions database and current budget sheets. Ask me any question like:\n- "Can I eat biryani today?"\n- "Can I buy shoes?"\n- "Should I buy a bike of ₹1,20,000?"\n- "Can I go to Goa?"';
    });
  }

  void _sendMessage() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    // Auto-dismiss the keyboard on message send
    FocusScope.of(context).unfocus();

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
            // Premium App Bar Header with Back Navigation & Online Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.cardDark.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.4),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      ref.read(dashboardIndexProvider.notifier).state = 0;
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primaryPurple,
                            size: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.emeraldGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.bgDark : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advisor AI',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.emeraldGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Online • Witty Financial Guru',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable chat view taking full remaining screen space
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0) + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Embed real-time insights dynamically inside the scrolling list view at index 0
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (insights.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, top: 4.0),
                            child: Text(
                              'REAL-TIME INSIGHTS',
                              style: AppTextStyles.caption(isDark: isDark).copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: insights.length,
                              itemBuilder: (context, idx) {
                                return _buildInsightCard(insights[idx], isDark);
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ],
                    );
                  }

                  // Offset messages by -1 since horizontal slider is at index 0
                  final msgIndex = index - 1;

                  if (msgIndex == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[msgIndex];
                  final isAi = msg['sender'] == 'ai';
                  return _buildMessageBubble(msg['text']!, isAi);
                },
              ),
            ),

            // Premium Floating Pill Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.cardDark.withOpacity(0.7) 
                    : Colors.white.withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.black.withOpacity(0.2) 
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _queryController,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask advisor, e.g. "Can I eat biryani today?"',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      width: 270,
      margin: const EdgeInsets.only(right: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderOpacity: 0.1,
        customBorder: Border(left: BorderSide(color: accentColor, width: 3.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              insight['description'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondaryDark,
                height: 1.35,
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
        constraints: const BoxConstraints(maxWidth: 270),
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
