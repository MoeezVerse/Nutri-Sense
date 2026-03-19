import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'nutrition_chat_screen.dart';
import 'nutritionists_list_screen.dart';
import '../widgets/pressable_scale.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Get in touch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D29),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chat with your personal nutritionist or find nutritionists near you.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FadeSlideIn(
                      delayMs: 20,
                      child: _ContactCard(
                        icon: FontAwesomeIcons.message,
                        title: 'Nutrition Assistant',
                        subtitle: 'Chat with your personal nutritionist. Get diet tips and meal advice based on your profile.',
                        primaryAction: 'Chat with Assistant',
                        compact: compact,
                        onPrimary: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NutritionChatScreen(),
                            ),
                          );
                        },
                        color: const Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeSlideIn(
                      delayMs: 100,
                      child: _ContactCard(
                        icon: FontAwesomeIcons.userDoctor,
                        title: 'Find nutritionists near you',
                        subtitle: 'See a list of nutritionists sorted by distance. Call or email the nearest ones.',
                        primaryAction: 'View nearby nutritionists',
                        compact: compact,
                        onPrimary: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NutritionistsListScreen(),
                            ),
                          );
                        },
                        color: const Color(0xFF3498DB),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FadeSlideIn(
                      delayMs: 170,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              FontAwesomeIcons.circleInfo,
                              color: Color(0xFF2ECC71),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'The assistant uses your profile for personalized advice. Add your details in Profile for better suggestions.',
                                style: TextStyle(
                                  fontSize: compact ? 11 : 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 20, compact ? 16 : 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.leaf,
                color: Color(0xFF2ECC71),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Nutri-Sense',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assistance & doctor contact',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryAction;
  final bool compact;
  final VoidCallback onPrimary;
  final Color color;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryAction,
    required this.compact,
    required this.onPrimary,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 10 : 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: compact ? 22 : 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D29),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PressableScale(
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(primaryAction),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({
    required this.child,
    required this.delayMs,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, widgetChild) {
        final dy = (1 - value) * 12;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, dy), child: widgetChild),
        );
      },
      child: child,
    );
  }
}
