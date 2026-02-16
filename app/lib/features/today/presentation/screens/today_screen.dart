import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Today Screen — главный экран приложения.
///
/// Показывает:
/// 1. Гороскоп дня (бесплатно, категории: General/Love/Work/Wellbeing)
/// 2. Карта дня (бесплатно, 1 карта)
/// 3. Расклад из 3 карт (premium gate)
///
/// UX: Fast path — всё видно без скролла на экранах ≥ 360px.
/// Disclaimer всегда виден внизу.

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  _HoroscopeCategory _selectedCategory = _HoroscopeCategory.general;
  bool _cardRevealed = false;

  @override
  Widget build(BuildContext context) {
    // TODO(stage3): Replace with real data from Riverpod providers
    // final reading = ref.watch(todayReadingProvider);
    final now = DateTime.now();
    const zodiacSign = 'gemini'; // TODO: from UserProfile
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.cosmicBackground),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverToBoxAdapter(
                child: _TodayAppBar(
                  dateStr: dateStr,
                  zodiacSign: zodiacSign,
                ),
              ),

              // Horoscope Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: _HoroscopeCard(
                    zodiacSign: zodiacSign,
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),
                ),
              ),

              // Tarot section header
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: _SectionHeader(title: 'CARD OF THE DAY'),
                ),
              ),

              // Tarot Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: _TarotCardWidget(
                    isRevealed: _cardRevealed,
                    onReveal: () => setState(() => _cardRevealed = true),
                    onTap3CardSpread: () => _onTap3CardSpread(context),
                  ),
                ),
              ),

              // Disclaimer
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: _DisclaimerBadge(),
                ),
              ),

              // Bottom padding for nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap3CardSpread(BuildContext context) {
    // TODO(stage4): Check subscription status, show paywall if not premium
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cosmicPurple,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _PremiumGateSheet(
        featureName: '3-Card Spread',
        description: 'Get deeper insights with Past · Present · Future spread.',
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class _TodayAppBar extends StatelessWidget {
  const _TodayAppBar({required this.dateStr, required this.zodiacSign});
  final String dateStr;
  final String zodiacSign;

  @override
  Widget build(BuildContext context) {
    final zodiacEmoji = _zodiacEmoji(zodiacSign);
    final zodiacName = zodiacSign[0].toUpperCase() + zodiacSign.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$zodiacEmoji $zodiacName'.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.celestialGold,
                  letterSpacing: 2.0,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Notification bell
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            color: AppTheme.textSecondary,
            onPressed: () {
              // TODO(stage3): Navigate to notification settings
            },
          ),
          // Profile
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            color: AppTheme.textSecondary,
            onPressed: () {
              // TODO(stage3): Navigate to settings/profile
            },
          ),
        ],
      ),
    );
  }

  String _zodiacEmoji(String sign) {
    const emojis = {
      'aries': '♈', 'taurus': '♉', 'gemini': '♊', 'cancer': '♋',
      'leo': '♌', 'virgo': '♍', 'libra': '♎', 'scorpio': '♏',
      'sagittarius': '♐', 'capricorn': '♑', 'aquarius': '♒', 'pisces': '♓',
    };
    return emojis[sign] ?? '✦';
  }
}

enum _HoroscopeCategory { general, love, work, wellbeing }

extension _HoroscopeCategoryExt on _HoroscopeCategory {
  String get label => switch (this) {
    _HoroscopeCategory.general => 'General',
    _HoroscopeCategory.love => 'Love',
    _HoroscopeCategory.work => 'Work',
    _HoroscopeCategory.wellbeing => 'Wellbeing',
  };

  String get emoji => switch (this) {
    _HoroscopeCategory.general => '✦',
    _HoroscopeCategory.love => '💫',
    _HoroscopeCategory.work => '⚡',
    _HoroscopeCategory.wellbeing => '🌿',
  };

  // TODO(stage3): Replace with real content from Firestore
  String get placeholder => switch (this) {
    _HoroscopeCategory.general =>
      'Today, the celestial energies align in your favor. Mercury\'s influence brings clarity of thought and sharpens your communication skills. This is an excellent day to share your ideas and connect with others. Trust your intuition — it leads you toward meaningful experiences.\n\n✨ For entertainment purposes only.',
    _HoroscopeCategory.love =>
      'Venus illuminates your path in matters of the heart. Whether you\'re single or partnered, today brings warm, harmonious energy to your relationships. Open your heart to authentic connection.\n\n✨ For entertainment purposes only.',
    _HoroscopeCategory.work =>
      'Your professional intuition is heightened today. Focus on collaborative projects and trust your creative instincts. A new opportunity may present itself — stay open and observant.\n\n✨ For entertainment purposes only.',
    _HoroscopeCategory.wellbeing =>
      'Take a mindful moment to honor your inner world today. Gentle movement, hydration, and moments of quiet reflection support your energy. Listen to what your body and mind need.\n\n⭐ For reflection only — not medical advice.',
  };
}

class _HoroscopeCard extends StatelessWidget {
  const _HoroscopeCard({
    required this.zodiacSign,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final String zodiacSign;
  final _HoroscopeCategory selectedCategory;
  final ValueChanged<_HoroscopeCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cosmicPurple,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppTheme.celestialGold.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.celestialGold.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const _SectionHeader(title: 'YOUR HOROSCOPE'),
                const Spacer(),
                // Offline indicator (placeholder)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.success.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Today',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 10,
                          fontFamily: 'Raleway',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: _HoroscopeCategory.values.map((cat) {
                final isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onCategoryChanged(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.celestialGold.withAlpha(30)
                            : AppTheme.deepIndigo,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.celestialGold
                              : AppTheme.celestialGold.withAlpha(30),
                        ),
                      ),
                      child: Text(
                        '${cat.emoji} ${cat.label}',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.celestialGold
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Horoscope text
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                selectedCategory.placeholder,
                key: ValueKey(selectedCategory),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.celestialGold,
        letterSpacing: 2.0,
      ),
    );
  }
}

class _TarotCardWidget extends StatelessWidget {
  const _TarotCardWidget({
    required this.isRevealed,
    required this.onReveal,
    required this.onTap3CardSpread,
  });

  final bool isRevealed;
  final VoidCallback onReveal;
  final VoidCallback onTap3CardSpread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cosmicPurple,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.celestialGold.withAlpha(50)),
      ),
      child: Column(
        children: [
          // Card display area
          GestureDetector(
            onTap: isRevealed ? null : onReveal,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.deepIndigo,
                    AppTheme.royalPurple.withAlpha(100),
                  ],
                ),
              ),
              child: isRevealed
                  ? _RevealedCard()
                  : _HiddenCard(),
            ),
          ),

          // 3-Card Spread premium gate
          Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppTheme.celestialGold.withAlpha(40),
                style: BorderStyle.solid,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap3CardSpread,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: AppTheme.celestialGold,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '3-Card Spread — Go Premium',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.celestialGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.celestialGold,
                        size: 12,
                      ),
                    ],
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

class _HiddenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 130,
            decoration: BoxDecoration(
              color: AppTheme.deepIndigo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.celestialGold.withAlpha(80),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 36,
                  color: AppTheme.celestialGold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to reveal your card',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO(stage3): Use actual card data from DailyReading
    return Row(
      children: [
        // Card image placeholder
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            width: 90,
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.deepIndigo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.celestialGold.withAlpha(120),
                width: 1.5,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⭐', style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text(
                  'XVII',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 14,
                    color: AppTheme.celestialGold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Card info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'THE STAR',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.celestialGold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.success.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    '↑ Upright',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hope · Renewal · Faith\nInspiration · Serenity',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '✨ For entertainment only',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 10,
                    color: AppTheme.textDisabled,
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

class _DisclaimerBadge extends StatelessWidget {
  const _DisclaimerBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '⭐ For entertainment purposes only · Not professional advice',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textDisabled,
          fontSize: 10,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PremiumGateSheet extends StatelessWidget {
  const _PremiumGateSheet({
    required this.featureName,
    required this.description,
  });

  final String featureName;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('🔒', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(
            featureName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.celestialGold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO(stage4): Navigate to Paywall
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.celestialGold,
                foregroundColor: AppTheme.midnightBlue,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text(
                'Unlock Premium',
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
