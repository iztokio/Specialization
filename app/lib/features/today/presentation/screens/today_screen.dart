import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tarot/domain/entities/tarot_card.dart';
import '../../domain/entities/daily_reading.dart';

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
    final readingAsync = ref.watch(todayReadingProvider);
    final zodiacSign = ref.watch(currentZodiacSignProvider);
    final language = ref.watch(appLanguageProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    final reading = readingAsync.valueOrNull;
    final drawnCard =
        reading != null && reading.drawnCards.isNotEmpty
            ? reading.drawnCards.first
            : null;

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
                    reading: reading,
                    language: language,
                    isLoading: readingAsync.isLoading,
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
                    drawnCard: drawnCard,
                    language: language,
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
    final hasPremium = ref.read(hasPremiumAccessProvider);
    if (hasPremium) {
      context.push(AppRoutes.tarotDraw);
      return;
    }
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
          // Notification bell → Settings
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            color: AppTheme.textSecondary,
            onPressed: () => context.go(AppRoutes.settings),
          ),
          // Profile → Settings
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            color: AppTheme.textSecondary,
            onPressed: () => context.go(AppRoutes.settings),
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

  /// Returns the text for this category from a real [DailyReading].
  String fromReading(DailyReading reading, String language) {
    final card =
        reading.drawnCards.isNotEmpty ? reading.drawnCards.first : null;
    return switch (this) {
      _HoroscopeCategory.general => reading.horoscope.get(language),
      _HoroscopeCategory.love =>
        card?.card.meanings.love.get(language) ??
            reading.horoscope.get(language),
      _HoroscopeCategory.work =>
        card?.card.meanings.work.get(language) ??
            reading.horoscope.get(language),
      _HoroscopeCategory.wellbeing =>
        card?.card.meanings.health.get(language) ??
            reading.horoscope.get(language),
    };
  }

  /// Fallback placeholder when no reading available yet.
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
    required this.reading,
    required this.language,
    required this.isLoading,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final String zodiacSign;
  final DailyReading? reading;
  final String language;
  final bool isLoading;
  final _HoroscopeCategory selectedCategory;
  final ValueChanged<_HoroscopeCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final text = reading != null
        ? selectedCategory.fromReading(reading!, language)
        : selectedCategory.placeholder;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isLoading
                        ? AppTheme.textDisabled.withAlpha(30)
                        : AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLoading
                          ? AppTheme.textDisabled.withAlpha(80)
                          : AppTheme.success.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLoading
                              ? AppTheme.textDisabled
                              : AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLoading ? 'Loading...' : 'Today',
                        style: TextStyle(
                          color: isLoading
                              ? AppTheme.textDisabled
                              : AppTheme.success,
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

          // Horoscope text or skeleton
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: isLoading
                ? _HoroscopeSkeleton()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      text,
                      key: ValueKey('$selectedCategory-${reading?.id}'),
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

/// Skeleton shimmer while horoscope is loading.
class _HoroscopeSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [1.0, 0.85, 0.9, 0.7])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 14,
              width: MediaQuery.sizeOf(context).width * width,
              decoration: BoxDecoration(
                color: AppTheme.deepIndigo,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
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
    required this.drawnCard,
    required this.language,
    required this.onReveal,
    required this.onTap3CardSpread,
  });

  final bool isRevealed;
  final DrawnCard? drawnCard;
  final String language;
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
              child: isRevealed && drawnCard != null
                  ? _RevealedCard(drawn: drawnCard!, language: language)
                  : _HiddenCard(showTapHint: !isRevealed),
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
  const _HiddenCard({required this.showTapHint});
  final bool showTapHint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/tarot/tarot_back.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
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
              ),
            ),
          ),
          if (showTapHint) ...[
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
        ],
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  const _RevealedCard({required this.drawn, required this.language});
  final DrawnCard drawn;
  final String language;

  @override
  Widget build(BuildContext context) {
    final card = drawn.card;
    final isUpright = drawn.position == TarotPosition.upright;
    final positionLabel = isUpright ? '↑ Upright' : '↓ Reversed';
    final cardName = _resolvedCardName(card, language);
    final assetPath = _cardAssetPath(card);
    final meaningText = card.meanings
        .getMeaning(position: drawn.position)
        .get(language);

    return Row(
      children: [
        // Card image
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: 90,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: AppTheme.deepIndigo,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.celestialGold.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('✦', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        _toRoman(card.number),
                        style: const TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 14,
                          color: AppTheme.celestialGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  cardName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.celestialGold,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isUpright
                        ? AppTheme.success.withAlpha(30)
                        : AppTheme.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUpright
                          ? AppTheme.success.withAlpha(80)
                          : AppTheme.warning.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    positionLabel,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: isUpright ? AppTheme.success : AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  meaningText,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Text(
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

  /// Asset path for the card image. Falls back to tarot_back.png if not available.
  String _cardAssetPath(TarotCard card) {
    if (card.arcana == TarotArcana.major && card.number >= 0 && card.number <= 21) {
      return 'assets/images/tarot/tarot_major_${card.number}.png';
    }
    // Minor arcana images not yet available — show back as placeholder
    return 'assets/images/tarot/tarot_back.png';
  }

  /// Resolved display name: prefers proper Major Arcana name over placeholder.
  String _resolvedCardName(TarotCard card, String language) {
    final fromEntity = card.getName(language);
    // If the entity has a real name (not 'Card N' placeholder), use it
    if (!fromEntity.startsWith('Card ') && !fromEntity.startsWith('Carta ') &&
        !fromEntity.startsWith('Карта ')) {
      return fromEntity;
    }
    // Fall back to the canonical Major Arcana name if available
    if (card.arcana == TarotArcana.major) {
      return _kMajorArcanaNames[card.number] ?? fromEntity;
    }
    return fromEntity;
  }

  String _toRoman(int n) {
    const numerals = [
      '0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
      'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI',
    ];
    return n >= 0 && n < numerals.length ? numerals[n] : '$n';
  }
}

/// Canonical Major Arcana card names (EN) for offline fallback.
const _kMajorArcanaNames = {
  0: 'The Fool',
  1: 'The Magician',
  2: 'The High Priestess',
  3: 'The Empress',
  4: 'The Emperor',
  5: 'The Hierophant',
  6: 'The Lovers',
  7: 'The Chariot',
  8: 'Strength',
  9: 'The Hermit',
  10: 'Wheel of Fortune',
  11: 'Justice',
  12: 'The Hanged Man',
  13: 'Death',
  14: 'Temperance',
  15: 'The Devil',
  16: 'The Tower',
  17: 'The Star',
  18: 'The Moon',
  19: 'The Sun',
  20: 'Judgement',
  21: 'The World',
};

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
                context.push(AppRoutes.paywall);
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
